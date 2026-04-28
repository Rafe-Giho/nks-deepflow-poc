# NHN Cloud NKS Terraform Harness

NHN Cloud NKS에서 PoC #1을 수행하기 위한 클러스터 생성 하네스입니다.

## 전제

- NHN Cloud NKS 표준 CNI는 Cilium이 아니라 Calico 계열입니다.
- Sidecarless PoC의 기본 CNI 조건은 `Calico-eBPF`입니다.
- Calico add-on의 `mode`는 클러스터 생성 시점에 결정하는 전제로 둡니다.
- Terraform은 클러스터와 노드 그룹 같은 NHN Cloud 리소스를 만들고, 클러스터 내부 앱 배포는 `kubectl apply -k`로 분리합니다.

## 준비값

NHN Cloud 콘솔/API에서 다음 값을 확인해 `terraform.tfvars`에 입력합니다.

- NHN Cloud 계정 ID
- Tenant ID
- API Password
- Region: `KR1`, `KR2`, `JP1`
- VPC network UUID
- VPC subnet UUID
- worker flavor UUID
- NKS worker node image UUID
- key pair name
- Kubernetes version
- availability zone

## 사용 순서

```powershell
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
terraform init
terraform plan
```

루트 디렉터리에서는 plan 전용 스크립트를 사용할 수 있습니다.

```powershell
.\scripts\15-terraform-plan-nhn-nks.ps1
```

이 프로젝트에서는 명시적으로 승인하기 전까지 `terraform apply`를 실행하지 않습니다.

## CNI 조건

기본값은 최신 NHN Cloud NKS 사용 가이드의 지원 목록 기준으로 다음을 사용합니다.

```hcl
calico_version  = "v3.30.2-nks2"
calico_mode     = "ebpf"
coredns_version = "1.8.4-nks2"
```

NHN Cloud NKS API 문서상 Calico add-on option은 `mode = vxlan | ebpf`입니다. eBPF 기반 검증이 목적이므로 PoC 기본값은 `ebpf`로 둡니다.

Terraform provider는 Terraform Registry 기준 최신 `nhn-cloud/nhncloud` `1.0.8`로 고정합니다.

## 주의

- `node_count`는 resize 리소스와 충돌하지 않도록 `ignore_changes`로 관리합니다.
- NKS 컨트롤 플레인은 NHN Cloud가 관리하므로 kube-apiserver/etcd 저수준 설정은 Terraform 관리 범위가 아닙니다.
- 클러스터 내부 관측 스택은 루트의 `infra/observability`와 `scripts/20-apply-observability.ps1`을 사용합니다.
- 실제 plan 실행 전 `terraform.tfvars`의 placeholder 값을 모두 실제 NHN Cloud 값으로 교체해야 합니다.
