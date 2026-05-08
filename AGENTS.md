# Project Agent Instructions

이 저장소에서 작업하는 AI/엔지니어는 이 파일을 우선 기준으로 삼는다.

## 현재 단일 목표

현재 PoC primary path는 다음이다.

```text
NHN Cloud NKS
  -> Istio Ambient
  -> DeepFlow
  -> DeepFlow ClickHouse/Grafana
  -> sidecarless-smoke web-was-db
```

이전 Cilium/Hubble, 직접 ClickHouse/Grafana, echo-server sample은 현재 primary가 아니다.

## Source Of Truth

작업 전 아래 문서를 우선 확인한다.

1. `docs/project-source-of-truth.md`
2. `docs/ai-work-harness.md`
3. `docs/validation-gates.md`
4. `docs/deprecated-paths.md`
5. `docs/poc-linux-runbook.md`

README보다 위 문서들이 더 구체적인 작업 기준이다.

## Primary Paths

수정/확장 기본 경로:

- `infra/mesh/istio-ambient`
- `infra/observability/deepflow`
- `infra/apps/smoke`
- `infra/terraform/nhn-nks`
- `infra/terraform/modules/istio-ambient`
- `infra/terraform/modules/deepflow`
- `scripts/00-check-prereq.ps1`
- `scripts/10-check-nhn-nks.ps1`
- `scripts/15-terraform-plan-nhn-nks.ps1`
- `scripts/20-install-istio-ambient.ps1`
- `scripts/21-check-istio-ambient.ps1`
- `scripts/30-install-deepflow.ps1`
- `scripts/31-check-deepflow.ps1`
- `scripts/40-deploy-smoke-app.ps1`
- `scripts/50-verify-poc-visibility.ps1`

## Deprecated Paths

다음 경로는 primary 작업에서 사용하지 않는다.

- `scripts/legacy`
- `infra/legacy`
- `infra/observability/legacy-clickhouse-grafana`

legacy 경로는 보존용이다. 사용자가 명시적으로 legacy 검증을 요청하지 않는 한 실행/수정/문서화 기본값으로 삼지 않는다.

## Execution Safety

- `terraform apply` 금지. 사용자가 명시 승인하기 전에는 `plan`까지만 수행한다.
- `kubectl apply`, `helm install/upgrade`, `istioctl install`은 실제 클러스터 변경이다. 사용자가 실행을 요청한 경우에만 수행한다.
- 분석/리뷰 요청에서는 읽기 전용 명령만 사용한다.
- 최신 NHN Cloud NKS, Istio Ambient, DeepFlow, Terraform provider 정보는 공식 문서를 확인한다.
- 비밀값, kubeconfig, `terraform.tfvars`, tfstate는 커밋하지 않는다.

## Change Workflow

1. 관련 파일을 먼저 읽는다.
2. `docs/project-source-of-truth.md`와 충돌하는지 확인한다.
3. legacy 경로가 아닌 primary 경로에 최소 변경한다.
4. 필요한 문서 링크를 함께 갱신한다.
5. 가능한 최소 검증을 실행한다.
6. 결과 보고에는 변경 사항, 검증 상태, 남은 리스크를 포함한다.

## Verification Defaults

기본 검증:

```powershell
kubectl kustomize .\infra\apps\smoke
C:\terraform\terraform.exe fmt -check -recursive
C:\terraform\terraform.exe validate
git diff --check
```

Terraform validate는 `infra/terraform/nhn-nks`에서 실행한다.

PowerShell 스크립트를 수정하면 Parser parse 검증을 수행한다.
