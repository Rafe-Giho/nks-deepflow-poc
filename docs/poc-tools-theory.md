# PoC 도구 및 개념 이론 정리

## 1. 전체 목표

이 PoC는 NHN Cloud NKS에서 다음 질문에 답하기 위한 검증입니다.

```text
애플리케이션 Pod에 Envoy sidecar를 넣지 않고도
Pod/Service/Namespace 기준 L4/L7 trace 가시성을 확보할 수 있는가?
```

목표 아키텍처:

```text
NHN Cloud NKS
  -> Calico-VXLAN or Calico-eBPF
  -> Istio Ambient
       -> ztunnel
       -> waypoint optional
  -> DeepFlow
       -> eBPF agent
       -> server
       -> ClickHouse
       -> Grafana
  -> web-was-db workloads
```

## 2. NHN Cloud NKS

NKS는 NHN Cloud의 관리형 Kubernetes입니다. 사용자는 worker node, 네트워크, add-on, kubeconfig를 사용하고, Kubernetes control plane은 NHN Cloud가 관리합니다.

PoC에서 NKS가 중요한 이유:

- 최종 표준화 대상 환경입니다.
- CNI 선택이 Pod 통신 방식과 성능에 영향을 줍니다.
- DeepFlow Agent가 worker node에서 eBPF 데이터를 수집하므로 node OS/kernel이 중요합니다.
- ClickHouse는 PVC가 필요하므로 StorageClass가 필요합니다.
- 강화된 보안 규칙을 쓰면 Pod/Node 통신 포트를 별도 허용해야 할 수 있습니다.

### 2.1 NKS CNI

NHN Cloud NKS는 문서 기준 Calico-VXLAN과 Calico-eBPF를 선택할 수 있습니다.

Calico-VXLAN:

- Linux kernel network stack과 VXLAN overlay를 사용합니다.
- kube-proxy가 활성화됩니다.
- Pod 간 통신이 VXLAN 캡슐화를 거칩니다.
- 운영 호환성은 좋지만 캡슐화 오버헤드가 있습니다.

Calico-eBPF:

- eBPF 기반 datapath를 사용합니다.
- kube-proxy를 eBPF가 대체합니다.
- Pod-to-Pod, ClusterIP-to-Pod 경로가 직접 통신에 가깝습니다.
- 지연 시간과 성능 측면에서 유리할 수 있습니다.
- Rocky, Ubuntu 계열 OS 제약과 보안 그룹 주의사항이 있습니다.

이 PoC에서 Calico/Felix는 DeepFlow의 대체재가 아닙니다. NKS 네트워크 조건을 확인하기 위한 기반 항목입니다.

## 3. Kubernetes 기본 개념

### 3.1 Namespace

Namespace는 Kubernetes 리소스의 논리적 격리 단위입니다.

이 PoC에서는 다음 namespace를 사용합니다.

- `istio-system`: Istio control plane, CNI, ztunnel
- `deepflow`: DeepFlow server, agent, ClickHouse, Grafana
- `sidecarless-smoke`: smoke web-was-db workload

Ambient mesh 편입은 namespace label로 제어합니다.

```yaml
metadata:
  labels:
    istio.io/dataplane-mode: ambient
```

### 3.2 Pod

Pod는 Kubernetes에서 배포되는 가장 작은 실행 단위입니다. 기존 Istio sidecar 방식은 Pod 안에 애플리케이션 container와 `istio-proxy` container가 함께 들어갑니다.

이 PoC의 핵심은 workload Pod에 `istio-proxy`가 없어야 한다는 점입니다.

### 3.3 Service

Service는 Pod 집합에 안정적인 DNS 이름과 가상 IP를 제공합니다.

예:

```text
smoke-was.sidecarless-smoke.svc.cluster.local
smoke-db.sidecarless-smoke.svc.cluster.local
```

DeepFlow와 Istio Ambient 검증에서는 Service 기준 호출이 중요합니다. waypoint는 기본적으로 Service 대상으로 들어오는 트래픽을 L7 처리합니다.

### 3.4 Deployment, DaemonSet, StatefulSet

Deployment:

- stateless workload 배포에 사용합니다.
- `smoke-was`, `deepflow-server`, `grafana` 같은 대상에 적합합니다.

DaemonSet:

- 모든 worker node에 1개씩 Pod를 배치합니다.
- `ztunnel`, `istio-cni-node`, `deepflow-agent`처럼 node-local 동작이 필요한 구성에 사용합니다.

StatefulSet:

- 안정적인 identity와 volume이 필요한 workload에 사용합니다.
- ClickHouse, MySQL 같은 저장소에 사용됩니다.

### 3.5 CRD

CRD는 Kubernetes API를 확장하는 방식입니다.

Istio와 Gateway API는 여러 CRD를 설치합니다. 예를 들어 waypoint는 Kubernetes Gateway API의 `Gateway` 리소스를 사용합니다.

## 4. Istio Ambient

Istio Ambient는 sidecar 없이 service mesh 기능을 제공하는 Istio data plane 방식입니다.

기존 sidecar mode:

```text
Pod
  -> app container
  -> istio-proxy sidecar
```

Ambient mode:

```text
Pod
  -> app container only

Node
  -> ztunnel

Optional
  -> waypoint
```

### 4.1 ztunnel

ztunnel은 Ambient의 node-level L4 data plane입니다.

역할:

- ambient workload 트래픽을 처리합니다.
- L4 secure overlay를 제공합니다.
- mTLS, identity 기반 인증/인가의 기반이 됩니다.
- node 단위로 배치되므로 Pod마다 proxy를 넣지 않습니다.

한계:

- ztunnel은 L4 중심입니다.
- HTTP method/path/header 같은 L7 조건을 처리하지 않습니다.

### 4.2 HBONE

HBONE은 Ambient에서 workload 간 보안 터널링에 사용되는 HTTP/2 기반 overlay입니다.

PoC에서 중요한 점:

- DeepFlow가 L4 flow는 볼 수 있어도, HBONE/mTLS 경로의 L7 payload를 어디까지 복원할 수 있는지는 실제 검증해야 합니다.
- 그래서 smoke workload에서 Ambient 적용 전/후, waypoint 적용 전/후를 비교하는 것이 중요합니다.

### 4.3 waypoint

waypoint는 Ambient에서 선택적으로 배치하는 Envoy 기반 L7 proxy입니다.

필요한 경우:

- HTTP routing
- retry, timeout, fault injection
- L7 authorization policy
- HTTP metrics
- access log
- tracing

waypoint는 애플리케이션 Pod 안에 들어가지 않습니다. namespace, service, workload 단위로 공유되는 proxy입니다.

PoC에서는 다음 단계로 검증합니다.

```bash
istioctl waypoint apply -n sidecarless-smoke --enroll-namespace --for service
```

### 4.4 Ambient 편입 label

Ambient mode에 넣으려면 namespace 또는 Pod에 다음 label을 붙입니다.

```bash
kubectl label namespace sidecarless-smoke istio.io/dataplane-mode=ambient
```

현재 smoke namespace manifest에는 이미 이 label이 있습니다.

```yaml
metadata:
  labels:
    istio.io/dataplane-mode: ambient
```

중요:

- `istio-injection=enabled`는 sidecar injection용입니다.
- Ambient namespace에는 `istio.io/dataplane-mode=ambient`를 사용합니다.
- 두 방식을 같은 namespace에서 섞지 않는 것이 안전합니다.

## 5. DeepFlow

DeepFlow는 eBPF 기반 observability 플랫폼입니다.

주요 목표:

- 애플리케이션 코드 수정 없이 수집합니다.
- sidecar 없이 네트워크/요청 가시성을 확보합니다.
- Kubernetes resource 정보를 자동 tag로 붙입니다.
- ClickHouse에 저장하고 Grafana에서 시각화합니다.

### 5.1 deepflow-agent

각 node에서 동작하는 DaemonSet입니다.

역할:

- eBPF 기반 네트워크/시스템 이벤트 수집
- Pod/Service 통신 관측
- L4 flow 수집
- 가능한 경우 L7 request log 수집
- DeepFlow server로 데이터 전송

주의:

- privileged 권한, host 접근, kernel feature가 필요할 수 있습니다.
- NKS 보안 정책과 worker node OS/kernel이 중요합니다.

### 5.2 deepflow-server

DeepFlow control/data 처리 구성입니다.

역할:

- agent 관리
- metadata 동기화
- 수집 데이터 처리
- ClickHouse/Grafana와 연계

### 5.3 AutoTagging

DeepFlow는 Kubernetes API에서 resource 정보를 가져와 관측 데이터에 자동 tag를 붙입니다.

예:

- cluster
- namespace
- node
- pod
- service
- deployment
- custom label

이 기능 때문에 단순 IP/port가 아니라 `source pod -> destination service` 형태로 분석할 수 있습니다.

### 5.4 AutoMetrics

AutoMetrics는 네트워크/요청 기반 metric을 자동 생성하는 기능입니다.

예:

- request count
- error count
- latency
- throughput
- service dependency

### 5.5 AutoTracing

AutoTracing은 애플리케이션 코드에 tracing SDK를 넣지 않고도 호출 관계를 추적하려는 기능입니다.

주의:

- 모든 언어/프로토콜/비동기 호출에서 완전한 trace가 항상 보장되는 것은 아닙니다.
- mTLS/HBONE, 암호화, 비표준 프로토콜에서는 L7 복원 범위가 제한될 수 있습니다.
- 필요하면 OpenTelemetry를 보완 도구로 붙입니다.

## 6. L4/L7 가시성

### 6.1 L4

L4는 TCP/UDP 계층입니다.

확인 가능한 것:

- source IP/port
- destination IP/port
- protocol
- byte/packet
- connection
- latency 일부

PoC 예:

```text
http-traffic Pod -> smoke-was Service:8080
sql-traffic Pod -> smoke-db Service:5432
```

### 6.2 L7

L7은 HTTP, PostgreSQL, MySQL 같은 애플리케이션 프로토콜 계층입니다.

확인 가능한 것:

- HTTP method
- URL/path
- status code
- request latency
- SQL command
- application protocol

Ambient에서는 ztunnel만으로는 L7 처리가 제한됩니다. L7 mesh 기능은 waypoint가 담당합니다. DeepFlow의 L7 관측은 eBPF/packet/protocol 분석 기반이므로, Ambient mTLS/HBONE 환경에서 어떤 정보가 보이는지 실측이 필요합니다.

## 7. ClickHouse

ClickHouse는 column-oriented OLAP database입니다.

관측 데이터에 적합한 이유:

- 시간순 대량 이벤트 저장에 강합니다.
- group by, filter, aggregation이 빠릅니다.
- flow log/request log처럼 많은 row를 다루기 좋습니다.
- retention/partition/order key 설계로 비용과 성능을 조절할 수 있습니다.

이 PoC에서는 DeepFlow chart가 ClickHouse를 함께 배포합니다.

운영 시 확인할 것:

- PVC 용량
- retention
- replica 수
- query 성능
- backup 필요 여부

## 8. Grafana

Grafana는 시각화 도구입니다.

PoC에서 보는 것:

- service map
- namespace별 traffic
- source/destination flow
- HTTP request/error/latency
- PostgreSQL/TCP traffic
- trace view

주의:

- Grafana가 뜬 것만으로 성공이 아닙니다.
- DeepFlow 데이터가 실제로 적재되어야 합니다.
- smoke traffic 기준으로 dashboard에서 확인되어야 합니다.

## 9. Terraform

Terraform은 인프라를 코드로 관리하는 도구입니다.

핵심 개념:

- provider: NHN Cloud, Kubernetes, Helm 같은 API 연동
- resource: 생성/관리 대상
- state: 현재 관리 중인 리소스 상태
- plan: 변경 예정 내용 계산
- apply: 실제 변경 실행
- lockfile: provider 버전과 checksum 재현성 관리

현재 PoC 원칙:

- NKS 클러스터는 Terraform `plan`까지만 검증합니다.
- Istio/DeepFlow는 먼저 스크립트와 Helm으로 검증합니다.
- PoC 성공 후 Helm provider/Kubernetes provider로 전환합니다.

권장 전환 순서:

```text
NKS cluster/node group
  -> NKS add-on option
  -> Istio Ambient
  -> DeepFlow
  -> smoke app
  -> real web-was-db
```

## 10. CI/CD

CI/CD는 실제 `web-was-db` 배포 자동화 단계입니다.

권장 pipeline:

```text
source commit
  -> test
  -> docker build
  -> image push
  -> manifest render
  -> kubectl diff
  -> kubectl apply
  -> rollout status
  -> smoke traffic
  -> DeepFlow visibility check
```

CI/CD에서 반드시 확인할 것:

- image tag 전략
- registry 인증
- kubeconfig/ServiceAccount 권한
- secret 주입 방식
- rollback 기준
- 배포 후 DeepFlow 관측 확인 절차

## 11. Smoke web-was-db 의미

현재 smoke workload는 실제 앱 전 단계의 최소 구조입니다.

```text
http-traffic CronJob
  -> smoke-was Deployment/Service

sql-traffic CronJob
  -> smoke-db Deployment/Service
```

이 구조로 확인하는 것:

- HTTP L7
- PostgreSQL 또는 TCP L4/L7
- namespace ambient 편입
- sidecar 부재
- DeepFlow tagging
- DeepFlow service map

실제 `web-was-db`는 이 검증이 성공한 뒤 같은 원리로 배포합니다.

## 12. 성공/실패 판단

성공:

- NKS에서 Istio Ambient가 정상 설치됩니다.
- `ztunnel`, `istio-cni`, `istiod`가 Ready입니다.
- workload Pod에 `istio-proxy`가 없습니다.
- DeepFlow Agent가 모든 worker node에서 Ready입니다.
- DeepFlow Grafana에서 smoke namespace의 L4 flow가 보입니다.
- HTTP 또는 PostgreSQL L7 request log가 보입니다.

보류:

- DeepFlow는 뜨지만 L7 복원이 제한됩니다.
- StorageClass/PVC 문제로 ClickHouse 안정성이 부족합니다.
- waypoint 적용 전후 결과가 불명확합니다.

실패:

- NKS에서 Ambient 설치 자체가 불가능합니다.
- DeepFlow Agent가 node 권한/kernel 문제로 동작하지 않습니다.
- sidecarless 상태에서 통신 안정성이 깨집니다.
- 운영 표준으로 허용하기 어려운 보안 예외가 필수입니다.

## 13. 공식 문서

- NHN Cloud NKS user guide: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
- Istio Ambient install: https://istio.io/latest/docs/ambient/install/istioctl/
- Istio Ambient workload label: https://istio.io/latest/docs/ambient/usage/add-workloads/
- Istio waypoint: https://istio.io/latest/docs/ambient/usage/waypoint/
- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
- DeepFlow deployment overview: https://deepflow.io/docs/ce-install/overview/
