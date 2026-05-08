# DeepFlow 단독 구축 가이드

이 문서는 NHN Cloud NKS에서 Istio 없이 DeepFlow만 설치해 Pod/Service traffic 가시성을 검증하는 절차입니다. 명령어는 Ubuntu 계열 Linux 기준입니다.

## 1. 목표

```text
NHN Cloud NKS
  -> DeepFlow
       -> deepflow-agent
       -> deepflow-server
       -> ClickHouse
       -> Grafana
  -> smoke web-was-db
```

성공 기준:

- DeepFlow Agent가 모든 worker node에서 Ready입니다.
- DeepFlow ClickHouse/Grafana가 Ready입니다.
- `sidecarless-smoke` workload traffic이 DeepFlow Grafana에서 Pod/Service/Namespace 기준으로 보입니다.
- Istio, ztunnel, waypoint, Kiali는 이 경로의 필수 구성요소가 아닙니다.

## 2. 작업 변수

```bash
export POC_ROOT="$HOME/sidecarless-poc"
export KUBECONFIG="$HOME/.kube/nhn-nks.yaml"
export DEEPFLOW_VERSION="6.6.018"

cd "$POC_ROOT"
```

## 3. 도구 설치

```bash
sudo apt-get update
sudo apt-get install -y curl wget ca-certificates gnupg lsb-release unzip jq git

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
kubectl version --client
```

Terraform NKS plan까지 확인할 경우에만 Terraform을 설치합니다.

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

## 4. NKS 사전 점검

```bash
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
kubectl get storageclass

kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.osImage}{"\t"}{.status.nodeInfo.kernelVersion}{"\n"}{end}'

kubectl -n kube-system get pods -o wide | egrep -i 'calico|typha|coredns' || true
kubectl -n kube-system get daemonset kube-proxy --ignore-not-found

kubectl auth can-i create daemonsets.apps -n deepflow
kubectl auth can-i create deployments.apps -n deepflow
kubectl auth can-i create statefulsets.apps -n deepflow
kubectl auth can-i create persistentvolumeclaims -n deepflow
```

## 5. Terraform NKS plan

이미 NKS가 준비되어 있으면 이 단계는 건너뜁니다. 여기서는 `plan`까지만 실행합니다.

```bash
cd "$POC_ROOT/infra/terraform/nhn-nks"
cp -n terraform.tfvars.example terraform.tfvars
vi terraform.tfvars

terraform fmt -check -recursive
terraform init -input=false
terraform validate
terraform plan -input=false

cd "$POC_ROOT"
```

## 6. DeepFlow 설치

기본 StorageClass를 확인합니다.

```bash
kubectl get storageclass

export STORAGE_CLASS="$(kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}' | head -1)"
echo "STORAGE_CLASS=${STORAGE_CLASS:-<none>}"
```

기본 StorageClass가 있으면 values 파일만 사용합니다.

```bash
helm repo add deepflow https://deepflowio.github.io/deepflow --force-update
helm repo update deepflow

helm upgrade --install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --version "$DEEPFLOW_VERSION" \
  -f "$POC_ROOT/infra/observability/deepflow/values/poc-values.yaml"
```

StorageClass를 명시해야 하면 아래처럼 설치합니다.

```bash
helm upgrade --install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --version "$DEEPFLOW_VERSION" \
  -f "$POC_ROOT/infra/observability/deepflow/values/poc-values.yaml" \
  --set global.storageClass="$STORAGE_CLASS"
```

Ready 상태를 확인합니다.

```bash
kubectl -n deepflow get pods,svc,pvc -o wide
kubectl -n deepflow wait --for=condition=Ready pod --all --timeout=900s
helm status deepflow -n deepflow
```

## 7. Smoke web-was-db 배포

현재 smoke manifest는 Ambient 경로에서도 재사용하므로 namespace label에 `istio.io/dataplane-mode=ambient`가 들어 있습니다. Istio가 설치되지 않은 DeepFlow-only 경로에서는 이 label은 동작하지 않지만, 혼동을 줄이기 위해 제거합니다.

```bash
kubectl kustomize "$POC_ROOT/infra/apps/smoke"
kubectl apply -k "$POC_ROOT/infra/apps/smoke"
kubectl label namespace sidecarless-smoke istio.io/dataplane-mode- --overwrite || true

kubectl -n sidecarless-smoke rollout status deployment/smoke-was --timeout=180s
kubectl -n sidecarless-smoke rollout status deployment/smoke-db --timeout=180s
kubectl get namespace sidecarless-smoke --show-labels
kubectl -n sidecarless-smoke get pods,svc,cronjob -o wide
```

## 8. 트래픽 생성

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

## 9. Grafana 확인

```bash
kubectl -n deepflow port-forward svc/deepflow-grafana 3000:80
```

브라우저에서 접속합니다.

```text
URL: http://localhost:3000
ID: admin
PW: deepflow
```

확인 항목:

- namespace: `sidecarless-smoke`
- `http-traffic -> smoke-was:8080`
- `sql-traffic -> smoke-db:5432`
- L4 flow
- 가능한 경우 HTTP/PostgreSQL request log
- Kubernetes Pod/Service/Namespace tag

## 10. 정리 명령

아래 명령은 리소스를 삭제합니다. 실제 환경에서는 별도 승인 후 실행합니다.

```bash
# kubectl delete namespace sidecarless-smoke
# helm uninstall deepflow -n deepflow
# kubectl delete namespace deepflow
```

## 11. 공식 문서

- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
- NHN Cloud NKS user guide: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
