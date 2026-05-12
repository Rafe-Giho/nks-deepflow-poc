# Validation Gates

각 단계는 다음 gate를 통과해야 다음 단계로 진행합니다.

## Gate 0. AI 작업 기준

목표:

- AI가 현재 구축 경로와 삭제된 과거 경로를 혼동하지 않도록 기준을 고정합니다.

통과 기준:

- `AGENTS.md` 존재
- `docs/ai/00-project-source-of-truth.md` 존재
- `docs/ai/04-deprecated-paths.md` 존재
- README가 새 문서를 링크함

검증:

```bash
test -f AGENTS.md
test -f docs/ai/00-project-source-of-truth.md
test -f docs/ai/04-deprecated-paths.md
rg -n "project-source-of-truth|deprecated-paths|ai-work-harness" README.md AGENTS.md docs
```

## Gate 1. NKS Preflight

목표:

- 대상 NKS가 DeepFlow 단독 경로와 Istio Ambient + Kiali 경로를 검증할 수 있는지 확인합니다.

통과 기준:

- kubeconfig context 확인
- worker node Ready
- NKS `csi-cinder` add-on 확인
- `sgh-cinder-sc` StorageClass 확인
- Calico/Felix 상태 확인
- CRD/DaemonSet/Deployment 생성 권한 확인

검증:

```bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get storageclass
kubectl get csidriver | grep cinder || true
kubectl -n kube-system get pods -o wide | grep -i cinder || true
kubectl get storageclass sgh-cinder-sc \
  -o jsonpath='{.provisioner}{"\t"}{.parameters.type}{"\t"}{.reclaimPolicy}{"\t"}{.volumeBindingMode}{"\n"}'
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.osImage}{"\t"}{.status.nodeInfo.kernelVersion}{"\n"}{end}'
kubectl -n kube-system get pods -o wide | egrep -i 'calico|typha|coredns' || true
kubectl auth can-i create daemonsets.apps -n istio-system
kubectl auth can-i create daemonsets.apps -n deepflow
```

## Gate 2. Terraform NKS Plan

목표:

- NKS Terraform 구성이 문법적으로 유효한지 확인합니다.

통과 기준:

- `terraform fmt -check -recursive` 성공
- `terraform validate` 성공
- 실제 tfvars가 있을 경우 `terraform plan` 성공

검증:

```bash
cd infra/terraform/nhn-nks
terraform fmt -check -recursive
terraform init -input=false
terraform validate
terraform plan -input=false
```

금지:

```text
terraform apply
```

## Gate 3A. DeepFlow 단독

목표:

- Istio 없이 DeepFlow Agent/Server/ClickHouse/Grafana가 준비되는지 확인합니다.

통과 기준:

- Helm release 정상
- DeepFlow Pod Ready
- Agent DaemonSet Ready
- PVC Bound
- PVC StorageClass가 `sgh-cinder-sc`
- Grafana 접근 가능
- smoke traffic이 DeepFlow에서 조회됨

검증:

```bash
helm repo add deepflow https://deepflowio.github.io/deepflow --force-update
helm repo update deepflow
kubectl apply -f infra/observability/deepflow/storageclass/sc-cinder.yaml
helm upgrade --install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --version "7.1.002" \
  -f infra/observability/deepflow/values/poc-values.yaml \
  --wait \
  --timeout 20m
kubectl -n deepflow get pods,svc,pvc -o wide
kubectl -n deepflow get pvc \
  -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,SC:.spec.storageClassName,VOLUME:.spec.volumeName'
kubectl -n deepflow wait --for=condition=Ready pod --all --timeout=900s
```

## Gate 3B. Istio Ambient + Kiali

목표:

- Ambient control/data plane과 Kiali가 정상 동작하는지 확인합니다.

통과 기준:

- Gateway API CRD 존재
- `istiod` Ready
- `istio-cni-node` Ready
- `ztunnel` Ready
- Prometheus Ready
- Kiali Ready
- `istioctl analyze` 주요 오류 없음

검증:

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts --force-update
helm repo update istio
kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install istio-base istio/base -n istio-system --wait
kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 \
  || kubectl apply --server-side \
    -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/experimental-install.yaml"
helm upgrade --install istiod istio/istiod -n istio-system --set profile=ambient --wait
helm upgrade --install istio-cni istio/cni -n istio-system --set profile=ambient --wait
helm upgrade --install ztunnel istio/ztunnel -n istio-system --wait
kubectl -n istio-system rollout status deployment/istiod --timeout=300s
kubectl -n istio-system rollout status daemonset/istio-cni-node --timeout=300s
kubectl -n istio-system rollout status daemonset/ztunnel --timeout=300s
kubectl apply -f "https://raw.githubusercontent.com/istio/istio/${ISTIO_RELEASE}/samples/addons/prometheus.yaml"
kubectl -n istio-system rollout status deployment/prometheus --timeout=300s
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
istioctl analyze
```

## Gate 4. Kiali 뒤 DeepFlow 추가

목표:

- Istio Ambient + Kiali 기준선 위에서 DeepFlow를 추가하고 관측 결과를 비교합니다.

통과 기준:

- Helm release 정상
- DeepFlow Pod Ready
- Agent DaemonSet Ready
- PVC Bound
- PVC StorageClass가 `sgh-cinder-sc`
- Grafana 접근 가능
- Kiali graph와 DeepFlow Service Map 비교 가능

검증:

```bash
helm repo add deepflow https://deepflowio.github.io/deepflow --force-update
helm repo update deepflow
kubectl apply -f infra/observability/deepflow/storageclass/sc-cinder.yaml
helm upgrade --install deepflow deepflow/deepflow \
  --namespace deepflow \
  --create-namespace \
  --version "7.1.002" \
  -f infra/observability/deepflow/values/poc-values.yaml \
  --wait \
  --timeout 20m
kubectl -n deepflow get pods,svc,pvc -o wide
kubectl -n deepflow get pvc \
  -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,SC:.spec.storageClassName,VOLUME:.spec.volumeName'
kubectl -n deepflow wait --for=condition=Ready pod --all --timeout=900s
```

## Gate 5. Smoke web-was-db

목표:

- sidecarless smoke workload에서 L4/L7 관측 가능성을 확인합니다.

통과 기준:

- `sidecarless-smoke` namespace ambient label 적용
- `smoke-was`, `smoke-db` Ready
- workload Pod에 `istio-proxy` 없음
- HTTP/SQL traffic job 완료
- DeepFlow 단독 경로에서는 DeepFlow Grafana에서 관련 flow 확인
- Istio Ambient + Kiali 경로에서는 Kiali graph에서 관련 workload/traffic 확인

검증:

```bash
kubectl apply -k infra/apps/smoke
kubectl -n sidecarless-smoke rollout status deployment/smoke-was --timeout=180s
kubectl -n sidecarless-smoke rollout status deployment/smoke-db --timeout=180s
kubectl get namespace sidecarless-smoke -L istio.io/dataplane-mode,istio.io/use-waypoint
```

## Gate 6. 실제 web-was-db

목표:

- 실제 애플리케이션을 same harness에 편입합니다.

통과 기준:

- 이미지 registry push 성공
- manifest render 성공
- rollout 성공
- DeepFlow에서 web -> was -> db 호출 경로 확인

## Gate 7. CI/CD

목표:

- 배포와 검증을 pipeline에 연결합니다.

통과 기준:

- build/test/push/deploy/rollout 단계 정의
- 배포 후 smoke traffic 생성
- DeepFlow visibility 확인 절차 포함

## Gate 8. Terraform 전환

목표:

- 성공한 구성을 재현 가능한 코드로 전환합니다.

통과 기준:

- NKS module plan 성공
- Istio Ambient module plan 성공
- DeepFlow module plan 성공
- app 배포 범위 결정
- apply 승인 절차 문서화
