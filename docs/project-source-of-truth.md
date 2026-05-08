# Project Source Of Truth

## 1. 현재 목표

이 프로젝트의 현재 목표는 NHN Cloud NKS에서 Istio Ambient와 DeepFlow를 사용해 sidecarless observability PoC를 수행하는 것입니다.

```text
NHN Cloud NKS
  -> Istio Ambient
  -> DeepFlow
  -> DeepFlow ClickHouse/Grafana
  -> smoke web-was-db
```

## 2. 성공 기준

- NKS에서 Istio Ambient가 설치되고 `ztunnel`, `istio-cni`, `istiod`가 Ready 상태입니다.
- `sidecarless-smoke` namespace가 ambient mode에 편입됩니다.
- smoke workload Pod에 `istio-proxy` sidecar가 없습니다.
- DeepFlow Agent가 worker node에서 Ready입니다.
- DeepFlow Grafana에서 `sidecarless-smoke` namespace의 L4 flow가 보입니다.
- HTTP 또는 PostgreSQL L7 request log/trace가 확인됩니다.

## 3. 현재 Primary 범위

### Infrastructure

- NHN Cloud NKS
- Calico-VXLAN 또는 Calico-eBPF 확인
- Terraform NKS plan

### Mesh

- Istio Ambient
- ztunnel
- optional waypoint

### Observability

- DeepFlow
- DeepFlow ClickHouse
- DeepFlow Grafana

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

위 항목은 legacy 또는 별도 비교 실험으로만 취급합니다.

## 5. Primary 파일

문서:

- `README.md`
- `docs/poc-harness-design.md`
- `docs/poc-linux-runbook.md`
- `docs/poc-tools-theory.md`
- `docs/validation-checklist.md`
- `docs/ai-work-harness.md`
- `docs/project-source-of-truth.md`
- `docs/validation-gates.md`
- `docs/task-playbooks.md`
- `docs/deprecated-paths.md`

Kubernetes/Istio/DeepFlow:

- `infra/mesh/istio-ambient`
- `infra/observability/deepflow`
- `infra/apps/smoke`

Terraform:

- `infra/terraform/nhn-nks`
- `infra/terraform/modules/istio-ambient`
- `infra/terraform/modules/deepflow`

Scripts:

- `scripts/00-check-prereq.ps1`
- `scripts/10-check-nhn-nks.ps1`
- `scripts/15-terraform-plan-nhn-nks.ps1`
- `scripts/20-install-istio-ambient.ps1`
- `scripts/21-check-istio-ambient.ps1`
- `scripts/30-install-deepflow.ps1`
- `scripts/31-check-deepflow.ps1`
- `scripts/40-deploy-smoke-app.ps1`
- `scripts/50-verify-poc-visibility.ps1`

## 6. 단계

```text
Phase 0: AI 작업 하네스 정비
Phase 1: NKS preflight
Phase 2: Istio Ambient 설치/검증
Phase 3: DeepFlow 설치/검증
Phase 4: smoke web-was-db 검증
Phase 5: 실제 web-was-db 배포
Phase 6: CI/CD 구성
Phase 7: Terraform 전환
```

## 7. 최신성 원칙

다음 항목은 변경 가능성이 있으므로 작업 전 공식 기준을 확인합니다.

- NHN Cloud NKS 지원 Kubernetes/Add-on version
- NHN Cloud NKS Calico mode/options
- Istio Ambient install command/profile
- Gateway API CRD version
- DeepFlow chart version
- Terraform NHN Cloud provider schema
