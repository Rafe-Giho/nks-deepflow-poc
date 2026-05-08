# Linux 실행 가이드

이 문서는 엔지니어가 Linux 터미널에서 그대로 복붙해 PoC를 진행할 수 있게 만든 Runbook입니다.

대상 구성:

```text
NHN Cloud NKS
  -> Istio Ambient
  -> DeepFlow
  -> ClickHouse
  -> Grafana
  -> smoke web-was-db
```

## 0. 전제

- 실행 OS: Ubuntu 계열 Linux 기준
- 대상 클러스터: NHN Cloud NKS
- 현재 문서 기준일: 2026-05-08
- Istio 공식 latest 기준: Gateway API CRD `v1.4.0`, ambient profile
- DeepFlow 공식 single-k8s 설치 기준: Helm chart `6.6.018`
- `terraform apply`는 이 문서에서 실행하지 않습니다. NKS 생성은 `plan`까지만 다룹니다.

## 1. 작업 변수 설정

프로젝트 위치와 kubeconfig 경로를 환경에 맞게 수정합니다.

```bash
export POC_ROOT="$HOME/sidecarless-poc"
export KUBECONFIG="$HOME/.kube/nhn-nks.yaml"
export DEEPFLOW_VERSION="6.6.018"
export GATEWAY_API_VERSION="v1.4.0"

cd "$POC_ROOT"
```

현재 컨텍스트가 NKS인지 먼저 확인합니다.

```bash
kubectl config current-context
kubectl get nodes -o wide
```

## 2. 로컬 도구 설치

이미 설치되어 있으면 이 단계는 건너뜁니다.

```bash
sudo apt-get update
sudo apt-get install -y curl wget ca-certificates gnupg lsb-release unzip jq git
```

### 2.1 Helm 설치

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

### 2.2 Istio CLI 설치

공식 설치 스크립트는 최신 Istio CLI를 내려받습니다.

```bash
curl -L https://istio.io/downloadIstio | sh -
export ISTIO_DIR="$(find "$PWD" -maxdepth 1 -type d -name 'istio-*' | sort -V | tail -1)"
export PATH="$ISTIO_DIR/bin:$PATH"
istioctl version --remote=false
```

계속 사용할 셸에 등록하려면 다음을 추가합니다.

```bash
echo "export PATH=\"$ISTIO_DIR/bin:\$PATH\"" >> ~/.bashrc
```

### 2.3 Terraform 설치

Ubuntu apt repository 방식입니다.

```bash
wget -O- https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

sudo apt-get update
sudo apt-get install -y terraform
terraform version
```

## 3. NKS 사전 점검

### 3.1 기본 상태

```bash
kubectl version --client
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
kubectl get storageclass
```

### 3.2 노드 OS/kernel 확인

DeepFlow는 eBPF 기반 수집을 사용하므로 worker node kernel과 OS를 반드시 확인합니다.

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.osImage}{"\t"}{.status.nodeInfo.kernelVersion}{"\n"}{end}'
```

### 3.3 NKS CNI/Calico/Felix 확인

NHN Cloud NKS는 Calico-VXLAN 또는 Calico-eBPF를 선택할 수 있습니다. Calico-eBPF에서는 kube-proxy가 비활성화될 수 있습니다.

```bash
kubectl -n kube-system get pods -o wide | egrep -i 'calico|typha|coredns' || true
kubectl -n kube-system get daemonset kube-proxy --ignore-not-found

for pod in $(kubectl -n kube-system get pods -o name | grep -i calico || true); do
  echo "===== $pod ====="
  kubectl -n kube-system logs "$pod" --tail=100 --all-containers \
    | egrep -i 'felix|bpf|kube-proxy' \
    | head -20 || true
done
```

### 3.4 권한 확인

Istio Ambient와 DeepFlow는 CRD, DaemonSet, privileged workload를 생성합니다.

```bash
kubectl auth can-i create customresourcedefinitions.apiextensions.k8s.io
kubectl auth can-i create daemonsets.apps -n istio-system
kubectl auth can-i create daemonsets.apps -n deepflow
kubectl auth can-i create deployments.apps -n deepflow
kubectl auth can-i create statefulsets.apps -n deepflow
kubectl auth can-i create persistentvolumeclaims -n deepflow
```

## 4. Terraform NKS plan

실제 NKS가 이미 있으면 이 단계는 참고용입니다. 여기서는 `plan`까지만 수행합니다.

```bash
cd "$POC_ROOT/infra/terraform/nhn-nks"
cp -n terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```

`terraform.tfvars`의 placeholder를 실제 NHN Cloud 값으로 바꿉니다.

```bash
terraform fmt -check -recursive
terraform init -input=false
terraform validate
terraform plan -input=false
```

루트로 돌아갑니다.

```bash
cd "$POC_ROOT"
```

## 5. Istio Ambient 설치

### 5.1 Gateway API CRD 설치

```bash
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 \
  || kubectl apply --server-side \
    -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/experimental-install.yaml"
```

### 5.2 Ambient profile 설치

```bash
istioctl install \
  -f "$POC_ROOT/infra/mesh/istio-ambient/istio-operator.yaml" \
  --skip-confirmation
```

### 5.3 Istio 구성 요소 대기

```bash
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status daemonset/istio-cni-node --timeout=300s
kubectl -n istio-system rollout status daemonset/ztunnel --timeout=300s
kubectl -n istio-system get pods,svc,daemonset,deployment -o wide
istioctl analyze
```

## 6. DeepFlow 설치

### 6.1 StorageClass 확인

기본 StorageClass가 있으면 자동 사용합니다. 없으면 `STORAGE_CLASS`를 직접 지정합니다.

```bash
kubectl get storageclass

export STORAGE_CLASS="$(kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' | head -1)"
echo "STORAGE_CLASS=${STORAGE_CLASS:-<none>}"
```

기본 StorageClass가 없으면 아래 값을 직접 입력합니다.

```bash
# export STORAGE_CLASS="your-storage-class-name"
```

### 6.2 DeepFlow values 생성

```bash
cat > /tmp/deepflow-values.yaml <<EOF
global:
  replicas: 1
EOF

if [ -n "${STORAGE_CLASS:-}" ]; then
  cat >> /tmp/deepflow-values.yaml <<EOF
  storageClass: "${STORAGE_CLASS}"
EOF
fi

cat /tmp/deepflow-values.yaml
```

### 6.3 Helm 설치

```bash
helm repo add deepflow https://deepflowio.github.io/deepflow --force-update
helm repo update deepflow

helm upgrade --install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --version "$DEEPFLOW_VERSION" \
  -f /tmp/deepflow-values.yaml
```

### 6.4 DeepFlow Ready 확인

```bash
kubectl -n deepflow get pods,svc,pvc -o wide
kubectl -n deepflow wait --for=condition=Ready pod --all --timeout=900s
helm status deepflow -n deepflow
```

Grafana 접속은 port-forward를 우선 사용합니다.

```bash
kubectl -n deepflow port-forward svc/deepflow-grafana 3000:80
```

브라우저에서 접속합니다.

```text
URL: http://localhost:3000
ID: admin
PW: deepflow
```

NodePort 접근이 허용되는 환경이면 다음 명령으로 URL을 확인할 수 있습니다.

```bash
NODE_PORT="$(kubectl get --namespace deepflow -o jsonpath='{.spec.ports[0].nodePort}' services deepflow-grafana)"
NODE_IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')"
echo "Grafana URL: http://${NODE_IP}:${NODE_PORT}"
echo "Grafana auth: admin:deepflow"
```

## 7. Smoke web-was-db 배포

### 7.1 Manifest 렌더링 확인

```bash
kubectl kustomize "$POC_ROOT/infra/apps/smoke"
```

### 7.2 배포

```bash
kubectl apply -k "$POC_ROOT/infra/apps/smoke"

kubectl -n sidecarless-smoke rollout status deployment/smoke-was --timeout=180s
kubectl -n sidecarless-smoke rollout status deployment/smoke-db --timeout=180s
kubectl -n sidecarless-smoke get pods,svc,cronjob -o wide
```

### 7.3 Ambient 편입 확인

```bash
kubectl get namespace sidecarless-smoke -L istio.io/dataplane-mode,istio.io/use-waypoint
```

`DATAPLANE-MODE`가 `ambient`여야 합니다.

### 7.4 Sidecar 부재 확인

```bash
kubectl -n sidecarless-smoke get pods \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.name}{" "}{end}{"\n"}{end}'

if kubectl -n sidecarless-smoke get pods \
  -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.name}{"\n"}{end}{end}' \
  | grep -qx 'istio-proxy'; then
  echo "ERROR: istio-proxy sidecar exists"
  exit 1
else
  echo "OK: no istio-proxy sidecar"
fi
```

## 8. L7 waypoint 선택 적용

Ambient 기본 계층은 ztunnel 기반 L4입니다. HTTP L7 정책/라우팅/액세스 로그를 명확히 검증하려면 waypoint를 적용합니다.

```bash
istioctl waypoint apply -n sidecarless-smoke --enroll-namespace --for service
kubectl get namespace sidecarless-smoke -L istio.io/use-waypoint
istioctl waypoint list -n sidecarless-smoke
kubectl -n sidecarless-smoke get gateway,pod,svc -o wide
```

## 9. 트래픽 생성

```bash
export TS="$(date +%Y%m%d%H%M%S)"

kubectl -n sidecarless-smoke create job \
  --from=cronjob/http-traffic \
  "http-traffic-${TS}"

kubectl -n sidecarless-smoke create job \
  --from=cronjob/sql-traffic \
  "sql-traffic-${TS}"

kubectl -n sidecarless-smoke wait --for=condition=complete "job/http-traffic-${TS}" --timeout=180s
kubectl -n sidecarless-smoke wait --for=condition=complete "job/sql-traffic-${TS}" --timeout=180s

kubectl -n sidecarless-smoke logs "job/http-traffic-${TS}"
kubectl -n sidecarless-smoke logs "job/sql-traffic-${TS}"
```

## 10. PoC 가시성 검증

### 10.1 Kubernetes 상태 확인

```bash
kubectl -n istio-system get pods,svc,daemonset,deployment -o wide
kubectl -n deepflow get pods,svc,pvc -o wide
kubectl -n sidecarless-smoke get pods,svc,jobs,cronjobs -o wide
```

### 10.2 Grafana에서 확인할 항목

DeepFlow Grafana에서 다음 기준으로 조회합니다.

```text
namespace = sidecarless-smoke
source service = http-traffic
destination service = smoke-was
destination port = 8080
protocol = HTTP

source service = sql-traffic
destination service = smoke-db
destination port = 5432
protocol = PostgreSQL or TCP
```

성공 판정:

- `sidecarless-smoke` namespace의 Pod/Service가 DeepFlow tag로 보입니다.
- `http-traffic -> smoke-was` L4 flow가 보입니다.
- HTTP request log 또는 service map이 보입니다.
- `sql-traffic -> smoke-db` TCP/PostgreSQL 흐름이 보입니다.
- workload Pod에 `istio-proxy` container가 없습니다.

## 11. 문제 발생 시 1차 점검

### 11.1 Istio Ambient

```bash
istioctl analyze
kubectl -n istio-system logs daemonset/ztunnel --tail=100
kubectl -n istio-system logs daemonset/istio-cni-node --tail=100
kubectl get namespace sidecarless-smoke -L istio.io/dataplane-mode,istio.io/use-waypoint
```

### 11.2 DeepFlow

```bash
helm status deepflow -n deepflow
kubectl -n deepflow describe pod -l app=deepflow-agent
kubectl -n deepflow logs daemonset/deepflow-agent --tail=100
kubectl -n deepflow get pvc
kubectl get events -A --sort-by=.metadata.creationTimestamp | tail -100
```

### 11.3 Smoke workload

```bash
kubectl -n sidecarless-smoke describe pod -l app=smoke-was
kubectl -n sidecarless-smoke describe pod -l app=smoke-db
kubectl -n sidecarless-smoke get endpoints smoke-was smoke-db
```

## 12. 실제 web-was-db로 확장할 때

smoke 검증이 성공하면 실제 앱을 같은 namespace 패턴으로 배포합니다.

권장 순서:

```text
1. web/was/db image build
2. registry push
3. manifest or Helm values render
4. namespace에 istio.io/dataplane-mode=ambient 적용
5. 필요 시 waypoint 적용
6. kubectl diff
7. kubectl apply
8. rollout status
9. DeepFlow Grafana에서 호출 경로 검증
```

배포 전 최소 체크:

```bash
kubectl create namespace web-was-db --dry-run=client -o yaml \
  | kubectl label --local -f - istio.io/dataplane-mode=ambient -o yaml \
  | kubectl apply -f -

kubectl get namespace web-was-db -L istio.io/dataplane-mode
```

## 13. 정리 명령

아래 명령은 리소스를 삭제합니다. 실제 환경에서는 별도 승인 후 실행합니다.

```bash
# kubectl delete namespace sidecarless-smoke
# helm uninstall deepflow -n deepflow
# kubectl delete namespace deepflow
# istioctl uninstall --purge -y
# kubectl delete namespace istio-system
```

## 14. 공식 문서

- Istio Ambient install: https://istio.io/latest/docs/ambient/install/istioctl/
- Istio workload ambient label: https://istio.io/latest/docs/ambient/usage/add-workloads/
- Istio waypoint: https://istio.io/latest/docs/ambient/usage/waypoint/
- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
- NHN Cloud NKS user guide: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
