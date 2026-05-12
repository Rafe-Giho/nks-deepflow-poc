# Istio Ambient + Kiali 구축 가이드

이 문서는 NHN Cloud NKS에서 Istio Ambient를 구축하고 Kiali로 sidecarless mesh를 확인하는 절차입니다. 마지막에 DeepFlow를 추가하는 선택 절차도 포함합니다. 명령어는 Ubuntu 계열 Linux 기준입니다.

## 1. 목표

기본 경로:

```text
NHN Cloud NKS
  -> Istio Ambient
       -> istiod
       -> istio-cni
       -> ztunnel
       -> waypoint optional
  -> Prometheus
  -> Kiali
  -> smoke web-was-db
```

선택 확장:

```text
Istio Ambient + Kiali
  -> DeepFlow
       -> eBPF Agent
       -> ClickHouse
       -> Grafana
```

## 2. Kiali 뒤에 DeepFlow를 추가하는 의미

의미가 있습니다. 다만 Kiali에 DeepFlow를 붙이는 native integration이 아니라, 두 관측 경로를 병렬로 두고 비교하는 구조입니다.

Kiali가 잘하는 것:

- Istio control plane, ambient namespace, ztunnel, waypoint 상태 확인
- Istio telemetry와 Prometheus 기반 service graph, health, traffic rate 확인
- Istio config validation과 waypoint enrollment 확인

DeepFlow가 보완하는 것:

- Istio 밖의 Pod/Service traffic까지 eBPF 기반으로 관측
- TCP/HTTP/SQL 등 protocol 관측과 Kubernetes AutoTagging
- ClickHouse 기반 장기 저장과 DeepFlow Grafana 대시보드
- Ambient 적용 전/후, waypoint 적용 전/후의 실제 L4/L7 관측 차이 비교

추가하지 않아도 되는 경우:

- 목표가 Istio topology, mesh health, waypoint 상태 확인뿐인 경우
- Prometheus/Kiali 기반 metric만으로 충분한 경우
- ClickHouse/Grafana/DeepFlow Agent 운영 비용을 이번 PoC 범위에서 제외하려는 경우

이 PoC에서는 Kiali 검증 뒤 DeepFlow를 추가하는 것을 권장합니다. 이유는 Kiali가 mesh 관점의 정합성을 보여주고, DeepFlow가 node/protocol 관점의 실제 traffic 가시성을 보여주기 때문입니다.

주의:

- Ambient의 HBONE/mTLS 경로에서는 DeepFlow가 L4 flow는 볼 수 있어도 L7 복원 범위는 제한될 수 있습니다.
- waypoint를 적용하면 L7 proxy 지점이 생기므로 Kiali와 DeepFlow 결과를 함께 비교할 가치가 커집니다.

## 3. 작업 변수

```bash
export POC_ROOT="$HOME/sidecarless-poc"
export KUBECONFIG="$HOME/.kube/nhn-nks.yaml"
export GATEWAY_API_VERSION="v1.4.0"
export ISTIO_RELEASE="release-1.29"
export DEEPFLOW_VERSION="7.1.002"

cd "$POC_ROOT"
```

## 4. 도구 설치

```bash
sudo apt-get update
sudo apt-get install -y curl wget ca-certificates gnupg lsb-release unzip jq git

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

curl -L https://istio.io/downloadIstio | sh -
export ISTIO_DIR="$(find "$PWD" -maxdepth 1 -type d -name 'istio-*' | sort -V | tail -1)"
export PATH="$ISTIO_DIR/bin:$PATH"
istioctl version --remote=false
```

## 5. NKS 사전 점검

```bash
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
kubectl get storageclass

kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.osImage}{"\t"}{.status.nodeInfo.kernelVersion}{"\n"}{end}'

kubectl -n kube-system get pods -o wide | egrep -i 'calico|typha|coredns' || true
kubectl -n kube-system get daemonset kube-proxy --ignore-not-found

kubectl auth can-i create customresourcedefinitions.apiextensions.k8s.io
kubectl auth can-i create daemonsets.apps -n istio-system
kubectl auth can-i create deployments.apps -n istio-system
kubectl auth can-i create daemonsets.apps -n deepflow
```

## 6. Istio Ambient 설치

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts --force-update
helm repo update istio

kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install istio-base istio/base \
  -n istio-system \
  --wait

kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 \
  || kubectl apply --server-side \
    -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/experimental-install.yaml"

helm upgrade --install istiod istio/istiod \
  -n istio-system \
  --set profile=ambient \
  --wait

helm upgrade --install istio-cni istio/cni \
  -n istio-system \
  --set profile=ambient \
  --wait

helm upgrade --install ztunnel istio/ztunnel \
  -n istio-system \
  --wait
```

검증합니다.

```bash
kubectl -n istio-system get pods,svc,daemonset,deployment -o wide
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status daemonset/istio-cni-node --timeout=300s
kubectl -n istio-system rollout status daemonset/ztunnel --timeout=300s
istioctl analyze
```

## 7. Prometheus 설치

Kiali는 topology graph, metric, health 계산에 Prometheus가 필요합니다. 아래 quick-start addon은 PoC용입니다. 운영 표준으로는 별도 Prometheus 구성이 필요합니다.

```bash
kubectl apply -f "https://raw.githubusercontent.com/istio/istio/${ISTIO_RELEASE}/samples/addons/prometheus.yaml"
kubectl -n istio-system rollout status deployment/prometheus --timeout=300s
kubectl -n istio-system get svc prometheus
```

## 8. Kiali 설치

Kiali 공식 권장 방식인 Kiali Operator Helm chart를 사용합니다. `anonymous` 인증은 PoC와 port-forward 접근 전제입니다. 공개 노출 환경에서는 사용하지 않습니다.

```bash
helm repo add kiali https://kiali.org/helm-charts --force-update
helm repo update kiali

helm upgrade --install kiali-operator kiali/kiali-operator \
  --namespace kiali-operator \
  --create-namespace \
  --set cr.create=true \
  --set cr.namespace=istio-system \
  --set cr.spec.auth.strategy="anonymous"

kubectl -n kiali-operator rollout status deployment/kiali-operator --timeout=300s
kubectl -n istio-system rollout status deployment/kiali --timeout=300s
kubectl -n istio-system get pods,svc -l app.kubernetes.io/name=kiali -o wide
```

Kiali에 접속합니다.

```bash
kubectl -n istio-system port-forward svc/kiali 20001:20001
```

브라우저에서 접속합니다.

```text
URL: http://localhost:20001
```

## 9. Smoke web-was-db 배포

```bash
kubectl kustomize "$POC_ROOT/infra/apps/smoke"
kubectl apply -k "$POC_ROOT/infra/apps/smoke"

kubectl -n sidecarless-smoke rollout status deployment/smoke-was --timeout=180s
kubectl -n sidecarless-smoke rollout status deployment/smoke-db --timeout=180s
kubectl get namespace sidecarless-smoke -L istio.io/dataplane-mode,istio.io/use-waypoint
kubectl -n sidecarless-smoke get pods,svc,cronjob -o wide
```

Sidecar가 없는지 확인합니다.

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

## 10. Waypoint 적용

Kiali에서 L7 waypoint 상태까지 확인하려면 waypoint를 적용합니다.

```bash
istioctl waypoint apply -n sidecarless-smoke --enroll-namespace --for service
kubectl get namespace sidecarless-smoke -L istio.io/dataplane-mode,istio.io/use-waypoint
istioctl waypoint list -n sidecarless-smoke
kubectl -n sidecarless-smoke get gateway,pod,svc -o wide
```

## 11. 트래픽 생성

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

## 12. Kiali 확인

Kiali UI에서 확인합니다.

- `istio-system`에 ztunnel이 감지되는지
- `sidecarless-smoke` namespace가 Ambient로 표시되는지
- `smoke-was`, `smoke-db`, `http-traffic`, `sql-traffic` workload가 graph에 보이는지
- waypoint 적용 후 L7 badge와 waypoint proxy가 보이는지
- Prometheus metric 기반 health와 traffic rate가 보이는지

Kubernetes에서도 확인합니다.

```bash
kubectl -n istio-system get pods -l app=ztunnel -o wide
kubectl -n sidecarless-smoke get pods,svc,gateway -o wide
istioctl analyze
```

## 13. 선택: Kiali 뒤에 DeepFlow 추가

Kiali baseline을 먼저 확인한 뒤 DeepFlow를 추가합니다.

```bash
kubectl get storageclass
kubectl get csidriver | grep cinder || true
kubectl -n kube-system get pods -o wide | grep -i cinder || true
kubectl apply -f "$POC_ROOT/infra/observability/deepflow/storageclass/sc-cinder.yaml"
kubectl get storageclass sgh-cinder-sc

helm repo add deepflow https://deepflowio.github.io/deepflow --force-update
helm repo update deepflow

helm upgrade --install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --version "$DEEPFLOW_VERSION" \
  -f "$POC_ROOT/infra/observability/deepflow/values/poc-values.yaml"

kubectl -n deepflow get pods,svc,pvc -o wide
kubectl -n deepflow wait --for=condition=Ready pod --all --timeout=900s
```

`poc-values.yaml`은 `global.storageClass: sgh-cinder-sc`를 기본값으로 사용합니다.

DeepFlow Grafana에 접속합니다.

```bash
kubectl -n deepflow port-forward svc/deepflow-grafana 3000:80
```

확인 항목:

- Kiali에서 보이는 `sidecarless-smoke` graph와 DeepFlow의 Service Map이 일치하는지
- DeepFlow에서 `http-traffic -> smoke-was:8080` L4/L7가 보이는지
- DeepFlow에서 `sql-traffic -> smoke-db:5432` TCP/PostgreSQL 흐름이 보이는지
- waypoint 적용 전/후 DeepFlow L7 복원 범위가 달라지는지
- Kiali에는 보이지 않는 node/pod/protocol 관측 정보가 DeepFlow에 보이는지

## 14. 정리 명령

아래 명령은 리소스를 삭제합니다. 실제 환경에서는 별도 승인 후 실행합니다.

```bash
# kubectl delete namespace sidecarless-smoke
# helm uninstall deepflow -n deepflow
# kubectl delete namespace deepflow
# helm uninstall kiali-operator -n kiali-operator
# kubectl delete kiali --all --all-namespaces
# kubectl delete namespace kiali-operator
# kubectl delete -f "https://raw.githubusercontent.com/istio/istio/${ISTIO_RELEASE}/samples/addons/prometheus.yaml"
# helm uninstall ztunnel -n istio-system
# helm uninstall istio-cni -n istio-system
# helm uninstall istiod -n istio-system
# helm uninstall istio-base -n istio-system
# kubectl delete namespace istio-system
```

## 15. 공식 문서

- Istio Ambient Helm install: https://istio.io/latest/docs/ambient/install/helm/
- Istio waypoint: https://istio.io/latest/docs/ambient/usage/waypoint/
- Istio Prometheus integration: https://istio.io/latest/docs/ops/integrations/prometheus/
- Kiali Helm install: https://kiali.io/docs/installation/installation-guide/install-with-helm/
- Kiali prerequisites: https://kiali.io/docs/installation/installation-guide/prerequisites/
- Kiali Ambient Mesh: https://kiali.io/docs/features/ambient/
- Kiali Prometheus config: https://kiali.io/docs/configuration/p8s-jaeger-grafana/prometheus/
- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
