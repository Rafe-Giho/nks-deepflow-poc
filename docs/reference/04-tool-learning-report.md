# PoC #1 주요 도구 학습 보고서

## 1. 학습 순서

현재 PoC 기준 학습 우선순위는 다음입니다.

1. NHN Cloud NKS
2. Istio Ambient
3. DeepFlow
4. ClickHouse
5. Grafana
6. CI/CD
7. Terraform

## 2. NHN Cloud NKS

NKS는 NHN Cloud의 관리형 Kubernetes입니다. 이 PoC의 최종 실행 환경입니다.

확인해야 할 이유:

- Istio Ambient는 CNI와 node-level traffic redirection에 민감합니다.
- DeepFlow는 eBPF/packet 기반 수집을 위해 worker node 권한과 kernel 조건이 중요합니다.
- ClickHouse는 PVC가 필요하므로 StorageClass 확인이 필요합니다.

주요 확인 항목:

- Kubernetes version
- worker node OS/kernel
- Calico-VXLAN 또는 Calico-eBPF
- kube-proxy 유무
- StorageClass
- node security group
- privileged DaemonSet 허용
- NKS add-on version

## 3. Istio Ambient

Istio Ambient는 기존 Envoy sidecar 없이 mesh 기능을 제공하는 Istio data plane 방식입니다.

핵심 구성:

- `istiod`: control plane
- `istio-cni`: Pod traffic redirection 준비
- `ztunnel`: node-level L4 secure overlay
- `waypoint`: optional L7 proxy

Ambient의 중요한 개념:

- workload Pod마다 Envoy sidecar를 넣지 않습니다.
- namespace 또는 Pod에 `istio.io/dataplane-mode=ambient` 라벨을 붙여 mesh에 편입합니다.
- 기본 mesh 기능은 ztunnel 기반 L4입니다.
- HTTP routing, L7 policy 같은 기능은 waypoint가 필요합니다.

PoC에서 확인할 것:

- ambient namespace 라벨 적용 여부
- sidecar container 부재
- ztunnel Ready
- waypoint 필요 여부
- Ambient 적용 후 DeepFlow 가시성 변화

## 4. DeepFlow

DeepFlow는 eBPF 기반 observability 플랫폼입니다. 코드 삽입 없이 L4 flow, L7 request log, AutoTracing, AutoMetrics, AutoProfiling을 수집하는 것을 목표로 합니다.

핵심 구성:

- `deepflow-agent`: 각 node에서 수집
- `deepflow-server`: agent 관리, 수집 데이터 처리
- `ClickHouse`: 관측 데이터 저장
- `Grafana`: dashboard 시각화

PoC에서 DeepFlow를 쓰는 이유:

- sidecar 없는 Pod에서도 네트워크/요청 가시성을 얻기 위함입니다.
- Kubernetes resource tag를 자동으로 붙여 Pod/Service/Namespace 기준으로 분석하기 위함입니다.
- Istio Ambient의 ztunnel/waypoint 경로를 포함해 L4 이상 trace 가능성을 검증하기 위함입니다.

검증할 데이터:

- L4 flow log
- L7 HTTP request log
- PostgreSQL request log
- service map
- AutoTracing
- RED metrics

주의할 점:

- eBPF 기반 수집은 kernel/권한 조건에 영향을 받습니다.
- Ambient mTLS/HBONE 경로에서 L7 복원 범위는 실제 검증해야 합니다.
- cross-thread/asynchronous trace는 DeepFlow만으로 부족할 수 있어 OpenTelemetry 보완 가능성을 남깁니다.

## 5. ClickHouse

ClickHouse는 대량의 flow/request/time-series 데이터를 빠르게 집계하기 위한 columnar DB입니다.

현재 PoC에서는 DeepFlow chart가 구성하는 ClickHouse를 우선 사용합니다.

확인할 것:

- PVC 생성 여부
- retention 설정
- DeepFlow table 생성 여부
- Grafana datasource 연결
- query 성능

직접 ClickHouse를 별도로 운영하는 것은 현재 1차 경로가 아닙니다. DeepFlow 기본 구성이 실패하거나 사내 표준 DB로 분리해야 할 때만 검토합니다.

## 6. Grafana

Grafana는 ClickHouse에 저장된 DeepFlow 데이터를 시각화합니다.

PoC dashboard에서 봐야 할 것:

- source/destination service
- namespace별 traffic
- Pod별 flow
- HTTP status/error
- request latency
- PostgreSQL request
- trace/service map

주의할 점:

- Grafana가 뜨는 것만으로 PoC 성공이 아닙니다.
- 실제 smoke traffic이 DeepFlow 데이터로 적재되고 조회되어야 합니다.
- dashboard는 DeepFlow schema에 맞춰야 합니다.

## 7. CI/CD

PoC 성공 후 실제 `web-was-db` 배포를 자동화하는 단계입니다.

필요한 작업:

- image build
- registry push
- manifest render
- deploy dry-run 또는 diff
- rollout status
- smoke traffic
- DeepFlow visibility check

권장 흐름:

```text
commit
  -> build
  -> unit/integration test
  -> image push
  -> deploy to NKS
  -> rollout check
  -> visibility smoke
```

## 8. Terraform

Terraform은 마지막 단계에서 PoC 성공 구성을 재현 가능한 코드로 고정하는 도구입니다.

관리 후보:

- NHN Cloud NKS
- node group
- NKS add-on option
- security group
- Istio Ambient Helm release
- DeepFlow Helm release
- smoke/web-was-db Kubernetes 리소스

주의:

- 현재 단계에서는 `plan`만 수행합니다.
- cluster 내부 리소스를 Terraform으로 모두 관리할지, CI/CD 배포로 분리할지 결정해야 합니다.
- 민감정보는 repository에 커밋하지 않습니다.

## 9. 한 문장 요약

이 PoC는 NHN Cloud NKS에서 Istio Ambient로 sidecarless mesh를 만들고, DeepFlow로 Pod들의 L4/L7 관측 데이터를 ClickHouse/Grafana에 연결해 실제 web-was-db와 CI/CD, Terraform 표준화까지 이어가기 위한 검증 프로젝트입니다.

## 10. 공식 문서

- NHN Cloud NKS 사용 가이드: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
- Istio Ambient: https://istio.io/latest/docs/ambient/
- Istio Ambient 설치: https://istio.io/latest/docs/ambient/install/istioctl/
- Istio Ambient workload 편입: https://istio.io/latest/docs/ambient/usage/add-workloads/
- DeepFlow single K8s 설치: https://deepflow.io/docs/ce-install/single-k8s/
- DeepFlow 기능: https://deepflow.io/docs/about/features/
