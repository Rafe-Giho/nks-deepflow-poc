# Project Source Of Truth

## 1. 현재 목표

이 프로젝트의 현재 목표는 NHN Cloud NKS에서 DeepFlow 기반 L4/L7 관측 경로를 검증하는 것입니다.

```text
NHN Cloud NKS
  -> DeepFlow
  -> DeepFlow ClickHouse/Grafana
  -> web-was-db traffic visibility
```

의존성 기준:

- ClickHouse/Grafana는 DeepFlow chart가 제공하는 구성을 primary로 사용합니다.
- 별도 수집 경로를 만들지 않고 DeepFlow Agent가 수집한 데이터를 기준으로 검증합니다.
- 현재 NKS에는 `csi-cinder` add-on이 추가되어 있다는 전제로, DeepFlow PVC는 `sgh-cinder-sc` StorageClass를 사용합니다.
- service mesh 검증 경로는 현재 범위에서 제외합니다.

## 2. 성공 기준

- DeepFlow Agent가 worker node에서 Ready입니다.
- DeepFlow Server/App/MySQL/ClickHouse/Grafana가 Ready입니다.
- DeepFlow PVC가 `sgh-cinder-sc` StorageClass로 Bound입니다.
- `k8s-3tier-app` web-was-db traffic이 정상 처리됩니다.
- DeepFlow ClickHouse와 Grafana에서 Pod/Service/Namespace 기준 L4 flow와 가능한 L7 request log가 보입니다.

## 3. 현재 Primary 범위

### Infrastructure

- NHN Cloud NKS
- NKS `csi-cinder` add-on
- `sgh-cinder-sc` StorageClass
- Calico/Felix 상태 확인
- Terraform NKS plan

### Observability

- DeepFlow
- DeepFlow Agent
- DeepFlow ClickHouse
- DeepFlow Grafana
- DeepFlow PVC on `sgh-cinder-sc`

### Application

- `k8s-3tier-app`
- 이후 실제 `web-was-db` 배포

## 4. 비범위

현재 primary PoC에서 제외합니다.

- Cilium/Hubble primary 검증
- 직접 ClickHouse/Grafana primary 배포
- echo-server sample workload
- service mesh 전용 검증 경로
- `sidecarless-demo`
- `sidecarless-observability`
- `sidecarless.network_events`

위 항목은 삭제된 과거 산출물입니다. 현재 구축 경로로 복원하지 않습니다.

## 5. Primary 파일

문서:

- `README.md`
- `docs/README.md`
- `docs/reference/01-poc-harness-design.md`
- `docs/team/01-build-guide.md`
- `docs/team/build-guide-deepflow-only.md`
- `docs/team/02-tool-concepts.md`
- `docs/team/03-validation-checklist.md`
- `docs/ai/README.md`
- `docs/ai/01-ai-work-harness.md`
- `docs/ai/00-project-source-of-truth.md`
- `docs/ai/03-validation-gates.md`
- `docs/ai/02-task-playbooks.md`
- `docs/ai/04-deprecated-paths.md`
- `docs/ai/05-decision-log.md`
- `docs/team/README.md`
- `docs/reference/README.md`

Kubernetes/DeepFlow:

- `infra/observability/deepflow`
- `k8s-3tier-app`

Terraform:

- `infra/terraform/nhn-nks`
- `infra/terraform/modules/deepflow`

실행 기준:

- 팀 구축 절차는 `docs/team/01-build-guide.md`를 기준으로 합니다.
- 실제 명령은 `docs/team/build-guide-deepflow-only.md`에 둡니다.
- Windows PowerShell 실행 래퍼는 유지하지 않습니다.

## 6. 단계

```text
Phase 0: AI 작업 하네스 정비
Phase 1: NKS preflight
Phase 2: DeepFlow 설치/검증
Phase 3: web-was-db 검증
Phase 4: CI/CD 구성
Phase 5: Terraform 전환
```

## 7. 최신성 원칙

다음 항목은 변경 가능성이 있으므로 작업 전 공식 기준을 확인합니다.

- NHN Cloud NKS 지원 Kubernetes/Add-on version
- NHN Cloud NKS `csi-cinder` StorageClass provisioner/options
- NHN Cloud NKS Calico mode/options
- Gateway API CRD version
- DeepFlow chart version
- Terraform NHN Cloud provider schema
