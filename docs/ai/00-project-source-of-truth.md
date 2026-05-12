# Project Source Of Truth

## 1. 현재 목표

이 프로젝트의 현재 목표는 NHN Cloud NKS에서 DeepFlow 단독 관측 경로와 Istio Ambient + Kiali mesh 가시화 경로를 분리해 검증하는 것입니다.

```text
1. NHN Cloud NKS
   -> DeepFlow
   -> DeepFlow ClickHouse/Grafana
   -> smoke web-was-db

2. NHN Cloud NKS
   -> Istio Ambient
   -> Prometheus
   -> Kiali
   -> smoke web-was-db
   -> optional DeepFlow
```

의존성 기준:

- ClickHouse/Grafana는 DeepFlow 없이도 구성 가능한 범용 저장소/시각화 도구입니다.
- 이 PoC에서는 별도 수집 경로를 만들지 않고 DeepFlow chart가 제공하는 ClickHouse/Grafana를 primary로 사용합니다.
- DeepFlow 설치 자체에 Istio는 필수가 아닙니다.
- Istio Ambient는 DeepFlow의 설치 조건이 아니라 sidecarless mesh 검증 대상입니다.
- Kiali는 Istio용 콘솔이므로 DeepFlow 단독 경로에는 포함하지 않습니다.
- Istio Ambient + Kiali 뒤의 DeepFlow 추가는 Kiali와 DeepFlow 관측 관점을 비교하기 위한 선택 확장입니다.
- Ambient 적용 후 L4/L7 관측 범위는 smoke traffic으로 별도 검증합니다.
- 현재 NKS에는 `csi-cinder` add-on이 추가되어 있다는 전제로, DeepFlow PVC는 `sgh-cinder-sc` StorageClass를 사용합니다.

## 2. 성공 기준

- DeepFlow 단독 경로에서 DeepFlow Agent가 worker node에서 Ready입니다.
- DeepFlow Grafana에서 `sidecarless-smoke` namespace의 L4 flow가 보입니다.
- Istio Ambient + Kiali 경로에서 `ztunnel`, `istio-cni`, `istiod`, Kiali가 Ready입니다.
- `sidecarless-smoke` namespace가 ambient mode에 편입됩니다.
- smoke workload Pod에 `istio-proxy` sidecar가 없습니다.
- Kiali에서 ambient namespace, workload graph, waypoint 상태가 보입니다.
- DeepFlow 추가 시 Kiali graph와 DeepFlow Service Map/L4/L7 결과를 비교할 수 있습니다.

## 3. 현재 Primary 범위

### Infrastructure

- NHN Cloud NKS
- NKS `csi-cinder` add-on
- `sgh-cinder-sc` StorageClass
- Calico-VXLAN 또는 Calico-eBPF 확인
- Terraform NKS plan

### Mesh

- Istio Ambient
- ztunnel
- optional waypoint
- Kiali
- Prometheus for Kiali

### Observability

- DeepFlow
- DeepFlow ClickHouse
- DeepFlow Grafana
- DeepFlow PVC on `sgh-cinder-sc`

### Application

- `sidecarless-smoke` namespace
- smoke `web-was-db` workload
- 이후 실제 `web-was-db` 배포

## 4. 비범위

현재 primary PoC에서 제외합니다.

- Cilium/Hubble primary 검증
- 직접 ClickHouse/Grafana primary 배포
- echo-server sample workload
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
- `docs/team/build-guide-istio-ambient-kiali.md`
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

Kubernetes/Istio/Kiali/DeepFlow:

- `infra/mesh/istio-ambient`
- `infra/observability/deepflow`
- `infra/apps/smoke`

Terraform:

- `infra/terraform/nhn-nks`
- `infra/terraform/modules/istio-ambient`
- `infra/terraform/modules/deepflow`

실행 기준:

- 팀 구축 절차는 `docs/team/01-build-guide.md`를 기준으로 합니다.
- 실제 명령은 `docs/team/build-guide-deepflow-only.md` 또는 `docs/team/build-guide-istio-ambient-kiali.md`에 둡니다.
- Windows PowerShell 실행 래퍼는 유지하지 않습니다.

## 6. 단계

```text
Phase 0: AI 작업 하네스 정비
Phase 1: NKS preflight
Phase 2A: DeepFlow 단독 설치/검증
Phase 2B: Istio Ambient + Kiali 설치/검증
Phase 3: smoke web-was-db 검증
Phase 4: Kiali 뒤 DeepFlow 추가 검증
Phase 5: 실제 web-was-db 배포
Phase 6: CI/CD 구성
Phase 7: Terraform 전환
```

## 7. 최신성 원칙

다음 항목은 변경 가능성이 있으므로 작업 전 공식 기준을 확인합니다.

- NHN Cloud NKS 지원 Kubernetes/Add-on version
- NHN Cloud NKS `csi-cinder` StorageClass provisioner/options
- NHN Cloud NKS Calico mode/options
- Istio Ambient install command/profile
- Kiali install command/profile
- Gateway API CRD version
- DeepFlow chart version
- Terraform NHN Cloud provider schema
