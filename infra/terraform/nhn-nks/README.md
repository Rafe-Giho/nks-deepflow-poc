# NHN Cloud NKS Terraform Harness

NHN Cloud NKS에서 DeepFlow 단독 경로와 Istio Ambient + Kiali 경로를 검증하기 위한 클러스터 생성 하네스입니다.

이 하네스는 NKS 클러스터와 기본 add-on 조건을 준비합니다. DeepFlow 단독 설치와 Istio Ambient + Kiali 설치는 초기 검증 단계에서 `docs/team/`의 분리된 구축 가이드로 검증하고, PoC 성공 후 `infra/terraform/modules`로 전환합니다.

## 전제

- NHN Cloud NKS 표준 CNI는 Calico 계열입니다.
- Istio Ambient와 DeepFlow는 NKS CNI 위에 설치되는 cluster add-on/workload입니다.
- Calico/Felix 검증은 NKS 네트워크 조건 확인 항목입니다.
- Calico add-on의 `mode`는 클러스터 생성 시점에 결정하는 전제로 둡니다.
- Terraform은 먼저 클러스터와 노드 그룹 같은 NHN Cloud 리소스를 만들고, 클러스터 내부 앱 배포는 PoC 성공 전까지 `kubectl`, `helm`, `istioctl`로 분리합니다.

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

```bash
cp -n terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
```

이 프로젝트에서는 명시적으로 승인하기 전까지 `terraform apply`를 실행하지 않습니다.

## CNI 조건

기본값은 최신 NHN Cloud NKS 사용 가이드의 지원 목록 기준으로 다음을 사용합니다.

```hcl
calico_version  = "v3.30.2-nks2"
calico_mode     = "ebpf"
coredns_version = "v1.8.3-nks1"
```

NHN Cloud NKS API 문서상 Calico add-on option은 `mode = vxlan | ebpf`입니다. DeepFlow eBPF 수집과 Istio Ambient 자체가 Calico-eBPF를 필수로 요구하는 것은 아니지만, PoC에서는 NKS sidecarless 네트워크 성능 검증을 위해 기본값을 `ebpf`로 둡니다. 운영 표준은 NKS 제약과 보안 정책에 맞춰 `vxlan` 또는 `ebpf` 중 다시 결정합니다.

Terraform provider는 Terraform Registry 기준 최신 `nhn-cloud/nhncloud` `1.0.8`로 고정합니다.

## 주의

- `node_count`는 resize 리소스와 충돌하지 않도록 `ignore_changes`로 관리합니다.
- NKS 컨트롤 플레인은 NHN Cloud가 관리하므로 kube-apiserver/etcd 저수준 설정은 Terraform 관리 범위가 아닙니다.
- 클러스터 내부 주 관측 스택은 `infra/observability/deepflow`와 `docs/team/build-guide-deepflow-only.md` 또는 `docs/team/build-guide-istio-ambient-kiali.md`의 DeepFlow 설치 절차를 사용합니다.
- 실제 plan 실행 전 `terraform.tfvars`의 placeholder 값을 모두 실제 NHN Cloud 값으로 교체해야 합니다.
