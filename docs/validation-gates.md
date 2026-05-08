# Validation Gates

각 단계는 다음 gate를 통과해야 다음 단계로 진행합니다.

## Gate 0. AI 작업 기준

목표:

- AI가 primary/legacy 경로를 혼동하지 않도록 기준을 고정합니다.

통과 기준:

- `AGENTS.md` 존재
- `docs/project-source-of-truth.md` 존재
- `docs/deprecated-paths.md` 존재
- README가 새 문서를 링크함

검증:

```powershell
Test-Path .\AGENTS.md
Test-Path .\docs\project-source-of-truth.md
Test-Path .\docs\deprecated-paths.md
rg -n "project-source-of-truth|deprecated-paths|ai-work-harness" README.md AGENTS.md docs
```

## Gate 1. NKS Preflight

목표:

- 대상 NKS가 Istio Ambient와 DeepFlow 검증을 받을 수 있는지 확인합니다.

통과 기준:

- kubeconfig context 확인
- worker node Ready
- StorageClass 확인
- Calico/Felix 상태 확인
- CRD/DaemonSet/Deployment 생성 권한 확인

검증:

```powershell
.\scripts\00-check-prereq.ps1
.\scripts\10-check-nhn-nks.ps1
```

## Gate 2. Terraform NKS Plan

목표:

- NKS Terraform 구성이 문법적으로 유효한지 확인합니다.

통과 기준:

- `terraform fmt -check -recursive` 성공
- `terraform validate` 성공
- 실제 tfvars가 있을 경우 `terraform plan` 성공

검증:

```powershell
.\scripts\15-terraform-plan-nhn-nks.ps1
```

금지:

```text
terraform apply
```

## Gate 3. Istio Ambient

목표:

- Ambient control/data plane을 설치하고 정상 동작을 확인합니다.

통과 기준:

- Gateway API CRD 존재
- `istiod` Ready
- `istio-cni-node` Ready
- `ztunnel` Ready
- `istioctl analyze` 주요 오류 없음

검증:

```powershell
.\scripts\20-install-istio-ambient.ps1
.\scripts\21-check-istio-ambient.ps1
```

## Gate 4. DeepFlow

목표:

- DeepFlow Agent/Server/ClickHouse/Grafana가 준비되는지 확인합니다.

통과 기준:

- Helm release 정상
- DeepFlow Pod Ready
- Agent DaemonSet Ready
- PVC Bound
- Grafana 접근 가능

검증:

```powershell
.\scripts\30-install-deepflow.ps1
.\scripts\31-check-deepflow.ps1
```

## Gate 5. Smoke web-was-db

목표:

- sidecarless smoke workload에서 L4/L7 관측 가능성을 확인합니다.

통과 기준:

- `sidecarless-smoke` namespace ambient label 적용
- `smoke-was`, `smoke-db` Ready
- workload Pod에 `istio-proxy` 없음
- HTTP/SQL traffic job 완료
- DeepFlow Grafana에서 관련 flow 확인

검증:

```powershell
.\scripts\40-deploy-smoke-app.ps1
.\scripts\50-verify-poc-visibility.ps1
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
