# PoC #1 NHN Cloud NKS 주요 도구 학습 보고서

## 1. 전체 그림

PoC #1의 실제 대상은 NHN Cloud NKS입니다. 따라서 기본 학습 대상은 Cilium/Hubble이 아니라 **NHN Cloud NKS, Calico-eBPF, Terraform, ClickHouse, Grafana**입니다.

```text
Terraform
  -> NHN Cloud NKS
  -> Calico-eBPF CNI
  -> sidecarless workloads
  -> network event source
  -> ClickHouse
  -> Grafana
```

Cilium/Hubble은 회의록의 초기 검토안으로 남기되, NHN Cloud NKS 표준 하네스의 기본 구성은 아닙니다.

## 2. 먼저 알아야 할 개념

| 개념 | 설명 | PoC에서 보는 포인트 |
| --- | --- | --- |
| NKS | NHN Cloud의 관리형 Kubernetes | 컨트롤 플레인은 NHN Cloud가 관리 |
| CNI | Pod 네트워크 플러그인 | NKS는 Calico-VXLAN/Calico-eBPF 기준 |
| Calico-eBPF | eBPF 기반 Calico datapath | Sidecarless 네트워크 표준 후보 |
| Sidecarless | 앱 Pod에 프록시 sidecar를 붙이지 않는 구조 | Envoy sidecar 오버헤드 제거 |
| Terraform | 인프라를 코드로 생성/관리 | NKS 클러스터와 노드 그룹 생성 |
| ClickHouse | 컬럼 기반 분석 DB | 네트워크 이벤트 저장/집계 |
| Grafana | 시각화 도구 | 관측 대시보드 구성 |

## 3. NHN Cloud NKS

NKS는 NHN Cloud의 관리형 Kubernetes입니다. 컨트롤 플레인은 NHN Cloud가 관리하고, 사용자는 워커 노드, 서비스, Pod, 애플리케이션 리소스를 관리합니다.

PoC에서 중요한 점:

- CNI를 NKS가 제공하는 방식에 맞춰야 합니다.
- Cilium을 기본 설치 대상으로 가정하면 안 됩니다.
- NKS 클러스터 생성, 노드 그룹, 버전, add-on은 Terraform/API로 관리 가능합니다.
- LoadBalancer, Block Storage, 보안 그룹 같은 NHN Cloud 인프라 연동을 고려해야 합니다.

## 4. Calico-eBPF

NHN Cloud NKS에서 Sidecarless PoC의 기본 CNI 후보입니다.

핵심:

- Calico-VXLAN은 기본에 가까운 안정형 선택입니다.
- Calico-eBPF는 eBPF 기반 datapath로 kube-proxy를 대체하는 방향입니다.
- Sidecarless PoC에서는 Calico-eBPF가 더 적합합니다.

먼저 학습할 것:

- Calico-VXLAN과 Calico-eBPF 차이
- kube-proxy 유무 확인 방법
- Calico-eBPF 지원 OS 조건
- enhanced security rules 사용 시 pod port 보안 그룹 조건
- NetworkPolicy가 eBPF 기반으로 적용되는 방식

확인 예시:

```powershell
kubectl -n kube-system get pods -o wide | Select-String -Pattern "calico|typha"
kubectl -n kube-system get daemonset kube-proxy --ignore-not-found
kubectl get nodes -o wide
```

## 5. Terraform

Terraform은 NHN Cloud NKS 클러스터를 반복 가능하게 만들기 위한 IaC 도구입니다.

현재 하네스:

- `infra/terraform/nhn-nks`
- `nhncloud_kubernetes_cluster_v1`
- Calico add-on
- CoreDNS add-on
- `calico_mode = "ebpf"`

먼저 학습할 것:

- provider 인증값: `user_name`, `tenant_id`, `password`, `auth_url`, `region`
- NKS 생성 필수값: VPC, subnet, flavor, image, keypair, Kubernetes version
- add-on 설정
- `terraform plan`과 `terraform apply`
- node count resize 시 `ignore_changes = [node_count]`를 쓰는 이유

## 6. ClickHouse

ClickHouse는 네트워크 이벤트 저장소입니다.

현재 테이블:

- `sidecarless.network_events`

주요 컬럼:

- `event_source`: nhn-flow-log, calico, ebpf-collector 등
- `event_scope`: vpc, node, pod 등
- `source_namespace`, `source_pod`, `source_ip`
- `destination_namespace`, `destination_pod`, `destination_ip`
- `l4_protocol`, `destination_port`
- `event_json`: 원문 보관

학습 포인트:

- `MergeTree`
- `PARTITION BY`
- `ORDER BY`
- TTL 보관 정책
- Grafana 조회용 read-only 계정

## 7. Grafana

Grafana는 ClickHouse 데이터를 시각화합니다.

현재 대시보드:

- `NHN NKS Sidecarless Network Events`
- 이벤트 수 추이
- verdict/action 집계
- source -> destination 상위 목록

주의:

- Grafana SQL은 ClickHouse에 그대로 전달됩니다.
- 운영 표준안에서는 read-only 계정과 인증 연동이 필요합니다.
- PoC에서는 데이터 소스가 확정되기 전까지 대시보드 schema를 유연하게 유지합니다.

## 8. 네트워크 이벤트 수집원 후보

NKS에서는 Hubble exporter를 기본으로 쓸 수 없으므로 flow 수집원을 별도 결정해야 합니다.

| 후보 | 장점 | 한계 |
| --- | --- | --- |
| NHN Cloud Network Flow Log | NHN Cloud 네트워크 계층과 정합성 좋음 | Pod/namespace 단위 분석 제한 가능 |
| Calico metrics | CNI 표준 구성과 잘 맞음 | 원문 flow보다 요약 지표에 가까움 |
| 별도 eBPF collector | Pod-level 이벤트 가능성 | 권한/보안/운영 리스크 큼 |
| Cilium/Hubble 별도 실험 | flow 관측 기능 학습에 좋음 | NKS 표준 하네스와 다름 |

## 9. 학습 우선순위

| 우선순위 | 학습 대상 | 이유 |
| --- | --- | --- |
| 1 | NHN Cloud NKS | 실제 수행 환경 |
| 2 | Calico-eBPF | Sidecarless 네트워크 핵심 |
| 3 | Terraform NHN provider | 클러스터 재현성 확보 |
| 4 | ClickHouse/Grafana | 관측 데이터 저장/시각화 |
| 5 | 네트워크 이벤트 수집원 | PoC 관측 품질 결정 |
| 6 | Cilium/Hubble | 비교/참고 학습 |

## 10. 보고용 설명

짧은 설명:

> 이 PoC는 NHN Cloud NKS에서 Calico-eBPF 기반 Sidecarless 구조를 검증합니다. 클러스터는 Terraform으로 만들고, 애플리케이션 Pod에는 Envoy 같은 sidecar를 붙이지 않습니다. 관측 데이터는 ClickHouse에 저장하고 Grafana로 시각화하는 방향이며, 실제 flow 수집원은 NHN Flow Log, Calico metrics, 별도 eBPF collector 중 NKS 제약에 맞춰 결정합니다.

핵심 메시지:

- NKS 기준에서는 Cilium/Hubble을 기본 전제로 두면 안 됩니다.
- Sidecarless 검증의 Primary는 Calico-eBPF입니다.
- 관측 저장/시각화 계층은 ClickHouse/Grafana로 유지합니다.
- 가장 큰 미정 사항은 pod-level flow 수집원입니다.

## 11. 참고 공식 문서

- NHN Cloud NKS 개요: https://docs.nhncloud.com/ko/Container/NKS/ko/overview/
- NHN Cloud NKS 사용 가이드: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
- NHN Cloud NKS API 가이드: https://docs.nhncloud.com/ko/Container/NKS/ko/public-api/
- NHN Cloud Terraform 사용 가이드: https://docs.nhncloud.com/ko/Compute/Instance/ko/terraform-guide/
- Grafana ClickHouse datasource: https://grafana.com/docs/plugins/grafana-clickhouse-datasource/latest/configure/
- ClickHouse table engines: https://clickhouse.com/docs/en/engines/table-engines

