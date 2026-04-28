# PoC #1 NHN Cloud NKS Sidecarless 설계안

## 1. 기준 변경

회의록의 최초 검토안은 Cilium + Hubble이었지만, 실제 수행 환경은 NHN Cloud NKS입니다. NHN Cloud NKS는 CNI를 Calico-VXLAN 또는 Calico-eBPF로 제공하므로, 이 프로젝트의 기본 방향은 다음으로 보정합니다.

- 기본 클러스터: NHN Cloud NKS
- 기본 CNI: Calico-eBPF
- 기본 IaC: NHN Cloud Terraform provider
- 기본 관측 저장/시각화: ClickHouse + Grafana
- 제외: NKS 기본 하네스에서 Cilium/Hubble 직접 설치

## 2. 판단 기준

| 기준 | 설명 |
| --- | --- |
| NKS 적합성 | NHN Cloud가 제공하는 NKS 기능과 add-on 범위 안에서 동작하는지 |
| Sidecarless 정합성 | 애플리케이션 Pod에 Envoy 같은 프록시 sidecar를 붙이지 않는지 |
| CNI 정합성 | Calico-eBPF 생성 조건을 만족하는지 |
| 관측성 | VPC/node/pod/service 중 어느 범위까지 flow를 볼 수 있는지 |
| 구현 난이도 | 5/20까지 실제 NKS에 구축 가능한지 |
| 보고 적합성 | 기존 sidecar 구조 대비 리소스/운영성 차이를 설명할 수 있는지 |

## 3. 우선순위별 방안

### 1순위. NKS + Calico-eBPF + ClickHouse/Grafana

Primary 방안입니다.

```text
NHN Cloud NKS
  -> Calico-eBPF CNI
  -> sidecarless workloads
  -> network event source
  -> ClickHouse
  -> Grafana
```

장점:

- NHN Cloud NKS 표준 조건과 가장 잘 맞습니다.
- kube-proxy를 eBPF로 대체하는 방향이라 Sidecarless 표준화 취지와 맞습니다.
- CNI를 클러스터 생성 시점부터 IaC로 고정할 수 있습니다.
- ClickHouse/Grafana 구성은 관측 데이터 소스가 바뀌어도 재사용 가능합니다.

주의점:

- Hubble 같은 pod-level flow UI는 기본 제공 경로가 아닙니다.
- Calico add-on `mode`는 생성 시점 조건으로 보고 접근해야 합니다.
- 실제 flow 수집원은 NHN Flow Log, Calico 메트릭, 별도 eBPF collector 중 하나로 확정해야 합니다.

적용 위치:

- `infra/terraform/nhn-nks`
- `infra/observability`
- `infra/workloads`
- `scripts/10-check-nhn-nks.ps1`

### 2순위. NKS + Calico-eBPF + 별도 eBPF collector

Pod 단위 flow가 반드시 필요하면 별도 eBPF collector를 검토합니다.

```text
NKS Calico-eBPF
  -> eBPF collector DaemonSet
  -> ClickHouse
  -> Grafana
```

장점:

- Hubble 없이도 pod-level 네트워크 이벤트 수집 가능성을 만들 수 있습니다.
- Sidecarless 원칙을 유지합니다.

주의점:

- NKS 보안 정책상 privileged/hostPath/BPF 접근 허용 여부 확인이 필요합니다.
- collector 선정과 스키마 정규화가 별도 과제입니다.
- PoC 일정상 1순위보다 구현 리스크가 큽니다.

### 3순위. NKS + NHN Cloud Network Flow Log + ClickHouse/Grafana

NHN Cloud의 네트워크 Flow Log를 이용해 VPC/노드 레벨 흐름을 수집하는 방안입니다.

장점:

- 클러스터 내부에 과도한 권한의 DaemonSet을 두지 않아도 됩니다.
- NHN Cloud 네트워크 계층과 잘 맞습니다.
- 보안/감사 관점의 트래픽 근거 자료로 쓰기 좋습니다.

주의점:

- Pod/namespace 단위 세부 분석은 제한될 수 있습니다.
- 로그 전달 대상과 ClickHouse 적재 경로를 별도 구성해야 합니다.

### 4순위. NKS + Calico-VXLAN fallback

Calico-eBPF 적용이 어려운 경우의 백업 방안입니다.

장점:

- NKS 기본값에 가까워 구축 리스크가 낮습니다.
- 일반 Kubernetes 워크로드 검증은 가능합니다.

주의점:

- eBPF 기반 Sidecarless 네트워크 표준 검증력은 약합니다.
- kube-proxy가 유지될 수 있어 PoC 메시지가 흐려집니다.

### 5순위. 별도 Cilium/Hubble 실험 클러스터

회의록의 원 검토안인 Cilium + Hubble은 NKS 표준 하네스가 아니라 비교/학습용 별도 실험으로 둡니다.

장점:

- Hubble 기반 flow 관측 경험을 확보할 수 있습니다.
- Cilium 기반 표준안과 NKS 기반 표준안의 차이를 비교할 수 있습니다.

주의점:

- NHN Cloud NKS 표준 적용안으로 직접 채택하기 어렵습니다.
- 운영 표준안 후보로 삼으려면 NKS에서 Cilium 지원 가능 여부를 별도 확인해야 합니다.

## 4. 권장 진행 방향

권장안은 다음입니다.

```text
Primary:
  Terraform으로 NHN NKS + Calico-eBPF 생성
  ClickHouse/Grafana 관측 저장소 구성
  sidecarless sample workload 검증

Parallel decision:
  flow source를 NHN Flow Log / Calico metrics / eBPF collector 중 선택
```

## 5. PoC 완료 기준

- Terraform으로 NKS 클러스터 생성 계획을 만들 수 있습니다.
- NKS 클러스터의 CNI가 Calico-eBPF 조건임을 확인합니다.
- 애플리케이션 Pod에 sidecar가 없습니다.
- 샘플 workload가 정상 통신합니다.
- ClickHouse/Grafana가 NKS 클러스터에 배포됩니다.
- 네트워크 이벤트 수집원 후보별 장단점과 최종 선택안을 제시합니다.
- 기존 sidecar 방식 대비 리소스/운영 복잡도 비교표를 작성합니다.

## 6. 남은 확인 사항

- 실제 사용할 NKS Kubernetes 버전과 Calico add-on 버전
- Calico-eBPF 지원 OS 이미지
- NKS 보안 정책상 privileged/eBPF collector 허용 여부
- NHN Cloud Network Flow Log의 전달 대상과 스키마
- ClickHouse를 PoC 내장형으로 둘지 외부 관리형으로 둘지

## 7. 참고 공식 문서

- NHN Cloud Terraform 사용 가이드: https://docs.nhncloud.com/ko/Compute/Instance/ko/terraform-guide/
- NHN Cloud NKS API 가이드: https://docs.nhncloud.com/ko/Container/NKS/ko/public-api/
- NHN Cloud NKS 사용 가이드: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/

