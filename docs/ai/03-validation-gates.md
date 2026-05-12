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

- 대상 NKS가 DeepFlow를 검증할 수 있는지 확인합니다.

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
kubectl -n kube-system get pods -o wide | egrep -i 'calico|felix|typha|coredns' || true
kubectl auth can-i create daemonsets.apps -n deepflow
kubectl auth can-i create deployments.apps -n deepflow
kubectl auth can-i create statefulsets.apps -n deepflow
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

## Gate 3. DeepFlow

목표:

- DeepFlow Agent/Server/ClickHouse/Grafana가 준비되는지 확인합니다.

통과 기준:

- Helm release 정상
- DeepFlow Pod Ready
- Agent DaemonSet Ready
- PVC Bound
- PVC StorageClass가 `sgh-cinder-sc`
- Grafana 접근 가능
- web-was-db traffic이 DeepFlow에서 조회됨

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

## Gate 4. web-was-db 앱

목표:

- `k8s-3tier-app`에서 L4/L7 관측 가능성을 확인합니다.

통과 기준:

- `sgh-web-ns`, `sgh-was-ns`, `sgh-db-ns` namespace 생성
- web/was/db Pod Ready
- Gateway/HTTPRoute Accepted
- 외부 HTTP 요청 정상 응답
- DeepFlow Grafana에서 관련 flow 확인

검증:

```bash
kubectl apply -f k8s-3tier-app
kubectl get pods -n sgh-web-ns -o wide
kubectl get pods -n sgh-was-ns -o wide
kubectl get pods -n sgh-db-ns -o wide
kubectl get gateway,httproute -n sgh-web-ns
```

## Gate 5. 실제 web-was-db

목표:

- 실제 애플리케이션을 same harness에 편입합니다.

통과 기준:

- 이미지 registry push 성공
- manifest render 성공
- rollout 성공
- DeepFlow에서 web -> was -> db 호출 경로 확인

## Gate 6. CI/CD

목표:

- 배포와 검증을 pipeline에 연결합니다.

통과 기준:

- build/test/push/deploy/rollout 단계 정의
- 배포 후 검증 traffic 생성
- DeepFlow visibility 확인 절차 포함

## Gate 7. Terraform 전환

목표:

- 성공한 구성을 재현 가능한 코드로 전환합니다.

통과 기준:

- NKS module plan 성공
- DeepFlow module plan 성공
- app 배포 범위 결정
- apply 승인 절차 문서화
