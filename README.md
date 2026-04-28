# NHN Cloud NKS Sidecarless PoC

NHN Cloud NKS 기준으로 Sidecarless 표준 아키텍처와 관측 체계를 검증하기 위한 PoC 작업 공간입니다.

회의록의 PoC #1은 원래 Cilium + Hubble 검토가 포함되어 있었지만, NHN Cloud NKS 기준에서는 기본 CNI를 **Calico-eBPF**로 두고 검증합니다. Cilium/Hubble은 NKS 표준 하네스가 아니라 별도 비교/대안 검토 항목입니다.

## PoC 범위

- NHN Cloud NKS 클러스터를 Terraform으로 생성
- NKS CNI는 Calico-eBPF 우선 적용
- 애플리케이션 Pod에는 sidecar를 붙이지 않음
- ClickHouse + Grafana 기반 관측 데이터 저장/시각화 골격 구성
- 기존 Istio + Envoy sidecar 방식 대비 리소스/운영 복잡도 비교

## 디렉터리 구성

```text
.
|-- docs/
|   |-- poc1-sidecarless-design-options.md
|   |-- poc1-tool-learning-report.md
|   `-- validation-checklist.md
|-- infra/
|   |-- terraform/
|   |   `-- nhn-nks/
|   |       |-- versions.tf
|   |       |-- variables.tf
|   |       |-- main.tf
|   |       |-- outputs.tf
|   |       |-- terraform.tfvars.example
|   |       `-- README.md
|   |-- observability/
|   |   |-- kustomization.yaml
|   |   |-- 00-namespace.yaml
|   |   |-- 10-clickhouse.yaml
|   |   `-- 20-grafana.yaml
|   `-- workloads/
|       |-- kustomization.yaml
|       `-- sample-http-workload.yaml
|-- scripts/
|   |-- 00-check-prereq.ps1
|   |-- 10-check-nhn-nks.ps1
|   |-- 15-terraform-plan-nhn-nks.ps1
|   |-- 20-apply-observability.ps1
|   |-- 30-deploy-sample-workload.ps1
|   `-- 40-smoke-test.ps1
|-- .editorconfig
`-- .gitignore
```

## 실행 순서

### 1. NKS 클러스터 생성

```powershell
Set-Location .\infra\terraform\nhn-nks
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
# terraform.tfvars 값 보정 후 실행
terraform init
terraform plan
```

또는 루트에서 plan 전용 스크립트를 실행합니다.

```powershell
.\scripts\15-terraform-plan-nhn-nks.ps1
```

`terraform apply`는 이 하네스 검토 단계에서 실행하지 않습니다.

### 2. NKS 조건 확인

```powershell
.\scripts\00-check-prereq.ps1
.\scripts\10-check-nhn-nks.ps1
```

확인할 핵심 조건:

- 대상이 NHN Cloud NKS인지
- CNI가 Calico인지
- PoC 기본 조건인 Calico-eBPF인지
- eBPF 모드에서 `kube-proxy` DaemonSet이 없는지
- 워커 노드 OS가 Calico-eBPF 지원 조건에 맞는지

### 3. 관측/샘플 워크로드 배포

```powershell
.\scripts\20-apply-observability.ps1
.\scripts\30-deploy-sample-workload.ps1
.\scripts\40-smoke-test.ps1
```

## 기본 아키텍처

```text
NHN Cloud NKS
  -> Calico-eBPF CNI
  -> sample workloads without sidecar
  -> network event source TBD
  -> ClickHouse
  -> Grafana
```

현재 하네스는 NKS 클러스터 조건, sidecarless 워크로드, ClickHouse/Grafana 저장/시각화 골격까지 준비합니다. 실제 네트워크 이벤트 수집원은 NKS에서 선택 가능한 방식에 맞춰 확정해야 합니다.

우선 검토 후보:

- NHN Cloud Network Flow Log 기반 VPC/노드 레벨 flow 수집
- Calico-eBPF/Calico 메트릭 기반 네트워크 상태 수집
- 별도 eBPF collector 기반 pod-level flow 수집

## 주요 문서

- 설계안/방향성: `docs/poc1-sidecarless-design-options.md`
- 주요 도구 학습 보고서: `docs/poc1-tool-learning-report.md`
- 검증 체크리스트: `docs/validation-checklist.md`
- NKS Terraform 하네스: `infra/terraform/nhn-nks/README.md`
