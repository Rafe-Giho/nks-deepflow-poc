# NHN Cloud NKS Istio Ambient + DeepFlow PoC

NHN Cloud NKS에서 **Istio Ambient 기반 sidecarless mesh**와 **DeepFlow 기반 L4/L7 trace 가시성**을 검증하기 위한 PoC 작업 공간입니다.

현재 PoC의 1차 목표는 다음 구성을 검증하는 것입니다.

```text
NHN Cloud NKS
  -> Istio Ambient
       -> ztunnel L4 secure overlay
       -> waypoint optional L7 processing
  -> DeepFlow
       -> deepflow-agent
       -> deepflow-server
       -> ClickHouse
       -> Grafana
  -> smoke web-was-db workload
```

성공 기준은 애플리케이션 Pod에 Envoy sidecar를 넣지 않고도 Pod/Service/Namespace 기준 L4 이상 가시성을 확보하고, 이후 실제 `web-was-db` 배포와 CI/CD, Terraform 전환으로 이어갈 수 있는 하네스를 만드는 것입니다.

## PoC 범위

- NHN Cloud NKS 조건 검증
- Istio Ambient 설치 및 ztunnel 동작 검증
- namespace 단위 ambient mesh 편입 검증
- waypoint 기반 L7 처리 가능성 검증
- DeepFlow 설치 및 eBPF/Agent 동작 검증
- DeepFlow 내 ClickHouse/Grafana 기반 시각화 검증
- smoke `web-was-db` 워크로드로 HTTP/PostgreSQL 흐름 검증
- 실제 `web-was-db` 애플리케이션 배포 전 CI/CD 준비 항목 정리
- 마지막 단계에서 Terraform 코드화할 범위 분리

## 디렉터리 구성

```text
.
|-- AGENTS.md
|-- docs/
|   |-- ai-work-harness.md
|   |-- decision-log.md
|   |-- deprecated-paths.md
|   |-- poc-harness-design.md
|   |-- poc-linux-runbook.md
|   |-- poc-tools-theory.md
|   |-- poc1-project-guide.md
|   |-- poc1-sidecarless-design-options.md
|   |-- poc1-tool-learning-report.md
|   |-- project-source-of-truth.md
|   |-- task-playbooks.md
|   |-- validation-gates.md
|   `-- validation-checklist.md
|-- infra/
|   |-- apps/
|   |   `-- smoke/
|   |-- legacy/
|   |   `-- workloads/
|   |-- mesh/
|   |   `-- istio-ambient/
|   |-- observability/
|   |   |-- deepflow/
|   |   `-- legacy-clickhouse-grafana/
|   |-- terraform/
|   |   |-- nhn-nks/
|   |   `-- modules/
|   |       |-- deepflow/
|   |       `-- istio-ambient/
|-- scripts/
|   |-- 00-check-prereq.ps1
|   |-- 10-check-nhn-nks.ps1
|   |-- 15-terraform-plan-nhn-nks.ps1
|   |-- 20-install-istio-ambient.ps1
|   |-- 21-check-istio-ambient.ps1
|   |-- 30-install-deepflow.ps1
|   |-- 31-check-deepflow.ps1
|   |-- 40-deploy-smoke-app.ps1
|   |-- 50-verify-poc-visibility.ps1
|   `-- legacy/
```

`infra/legacy`, `scripts/legacy`, `infra/observability/legacy-clickhouse-grafana`는 보존용입니다. 현재 1차 경로는 DeepFlow Helm chart가 배포하는 ClickHouse/Grafana와 `infra/apps/smoke`입니다.

## 실행 순서

### 1. 도구 및 NKS 조건 확인

```powershell
.\scripts\00-check-prereq.ps1
.\scripts\10-check-nhn-nks.ps1
```

확인할 핵심 조건:

- 대상 클러스터가 NHN Cloud NKS인지
- worker node OS/kernel이 DeepFlow eBPF 수집에 적합한지
- 기본 StorageClass 또는 DeepFlow용 StorageClass가 있는지
- NKS CNI가 Calico-VXLAN 또는 Calico-eBPF인지
- Istio CNI/ztunnel 배포에 필요한 권한이 있는지

### 2. Istio Ambient 설치 및 검증

```powershell
.\scripts\20-install-istio-ambient.ps1
.\scripts\21-check-istio-ambient.ps1
```

설치 스크립트는 Gateway API CRD가 없으면 공식 Gateway API `v1.4.0` experimental CRD를 server-side apply로 설치하고, `istioctl install --set profile=ambient` 흐름을 사용합니다.

### 3. DeepFlow 설치 및 검증

```powershell
.\scripts\30-install-deepflow.ps1
.\scripts\31-check-deepflow.ps1
```

DeepFlow는 공식 Helm chart 기준으로 설치합니다. PoC에서는 DeepFlow chart가 구성하는 ClickHouse/Grafana를 우선 사용합니다.

### 4. Smoke web-was-db 배포 및 가시성 검증

```powershell
.\scripts\40-deploy-smoke-app.ps1
.\scripts\50-verify-poc-visibility.ps1
```

smoke workload는 다음 흐름을 만듭니다.

```text
http-client -> smoke-was HTTP service
sql-client  -> smoke-db PostgreSQL service
```

검증 포인트:

- workload Pod에 `istio-proxy` sidecar가 없는지
- namespace가 `istio.io/dataplane-mode=ambient`로 편입됐는지
- ztunnel이 Ready인지
- DeepFlow Agent가 각 노드에서 Ready인지
- DeepFlow Grafana에서 L4 flow, L7 request log, service map 또는 trace를 확인할 수 있는지

### 5. Terraform plan

```powershell
.\scripts\15-terraform-plan-nhn-nks.ps1
```

현재 단계에서는 `terraform plan`까지만 수행합니다. `terraform apply`는 명시 승인 전 실행하지 않습니다.

## 주요 문서

- AI 작업 기준: `AGENTS.md`
- AI 작업 하네스: `docs/ai-work-harness.md`
- 프로젝트 단일 기준: `docs/project-source-of-truth.md`
- Deprecated 경로: `docs/deprecated-paths.md`
- 작업 플레이북: `docs/task-playbooks.md`
- 검증 게이트: `docs/validation-gates.md`
- 의사결정 기록: `docs/decision-log.md`
- PoC 하네스 설계: `docs/poc-harness-design.md`
- Linux 실행 가이드: `docs/poc-linux-runbook.md`
- 도구/개념 이론 정리: `docs/poc-tools-theory.md`
- 프로젝트 가이드: `docs/poc1-project-guide.md`
- 설계안/방향성: `docs/poc1-sidecarless-design-options.md`
- 도구 학습 보고서: `docs/poc1-tool-learning-report.md`
- 검증 체크리스트: `docs/validation-checklist.md`
- NKS Terraform 하네스: `infra/terraform/nhn-nks/README.md`

## 공식 기준

- Istio Ambient 공식 문서: https://istio.io/latest/docs/ambient/
- Istio Ambient 설치: https://istio.io/latest/docs/ambient/install/istioctl/
- Istio Ambient workload 편입: https://istio.io/latest/docs/ambient/usage/add-workloads/
- DeepFlow single K8s 설치: https://deepflow.io/docs/ce-install/single-k8s/
- DeepFlow 기능 개요: https://deepflow.io/docs/about/features/
- NHN Cloud NKS 사용 가이드: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
