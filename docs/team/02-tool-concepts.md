# PoC 도구 및 개념 이론 정리

## 1. 전체 목표

이 PoC는 NHN Cloud NKS에서 다음 질문에 답하기 위한 검증입니다.

```text
애플리케이션 Pod에 별도 sidecar를 넣지 않고도
Pod/Service/Namespace 기준 L4/L7 trace 가시성을 확보할 수 있는가?
```

목표 아키텍처:

```text
NHN Cloud NKS
  -> Calico network
  -> DeepFlow
       -> deepflow-agent
       -> deepflow-server
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

### 2.1 NKS CNI와 Felix

NHN Cloud NKS는 Calico 계열 네트워크를 사용합니다. Calico의 Felix는 각 node에서 endpoint, route, policy 상태를 프로그래밍하는 핵심 컴포넌트입니다.

이 PoC에서 Calico/Felix는 DeepFlow의 대체재가 아닙니다. NKS 네트워크 조건을 확인하기 위한 기반 항목입니다.

확인 포인트:

- worker node가 Ready인지
- Calico/Felix 관련 Pod가 Running인지
- CoreDNS가 정상인지
- Pod 간, Service 간 통신이 정상인지

## 3. Kubernetes 기본 개념

### 3.1 Namespace

Namespace는 Kubernetes 리소스의 논리적 격리 단위입니다.

이 PoC에서는 다음 namespace를 사용합니다.

- `deepflow`: DeepFlow server, agent, ClickHouse, Grafana
- `sgh-web-ns`, `sgh-was-ns`, `sgh-db-ns`: 실제 3-tier 앱

### 3.2 Pod

Pod는 Kubernetes에서 배포되는 가장 작은 실행 단위입니다.

DeepFlow는 Pod 안에 별도 collector container를 넣지 않고 node-level Agent로 traffic을 관측합니다. 그래서 애플리케이션 manifest를 크게 바꾸지 않고도 관측 데이터를 얻는 것이 목표입니다.

### 3.3 Service

Service는 Pod 집합에 안정적인 DNS 이름과 가상 IP를 제공합니다.

예:

```text
sgh-web-svc.sgh-web-ns.svc.cluster.local
sgh-was-svc.sgh-was-ns.svc.cluster.local
sgh-db-svc.sgh-db-ns.svc.cluster.local
```

DeepFlow 검증에서는 Service 기준 호출이 중요합니다. Pod IP는 재생성될 수 있지만 Service와 Kubernetes tag는 호출 관계를 이해하기 쉽게 만듭니다.

### 3.4 Deployment, DaemonSet, StatefulSet

Deployment:

- stateless workload 배포에 사용합니다.
- web/was 같은 대상에 적합합니다.

DaemonSet:

- 모든 worker node에 1개씩 Pod를 배치합니다.
- `deepflow-agent`처럼 node-local 동작이 필요한 구성에 사용합니다.

StatefulSet:

- 안정적인 identity와 volume이 필요한 workload에 사용합니다.
- DB, ClickHouse, MySQL 같은 저장소에 사용됩니다.

### 3.5 CRD

CRD는 Kubernetes API를 확장하는 방식입니다.

DeepFlow chart는 필요한 Kubernetes 리소스를 Helm으로 배포하고, NGINX Gateway Fabric과 cert-manager 같은 외부 구성은 별도 CRD를 사용할 수 있습니다.

## 4. DeepFlow

DeepFlow는 eBPF 기반 observability 플랫폼입니다.

주요 목표:

- 애플리케이션 코드 수정 없이 수집합니다.
- sidecar 없이 네트워크/요청 가시성을 확보합니다.
- Kubernetes resource 정보를 자동 tag로 붙입니다.
- ClickHouse에 저장하고 Grafana에서 시각화합니다.

### 4.1 deepflow-agent

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
- Agent가 node마다 Ready인지가 첫 번째 성공 기준입니다.

### 4.2 deepflow-server

DeepFlow control/data 처리 구성입니다.

역할:

- agent 관리
- metadata 동기화
- 수집 데이터 처리
- ClickHouse/Grafana와 연계

### 4.3 AutoTagging

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

### 4.4 AutoMetrics

AutoMetrics는 네트워크/요청 기반 metric을 자동 생성하는 기능입니다.

예:

- request count
- error count
- latency
- throughput
- service dependency

### 4.5 AutoTracing

AutoTracing은 애플리케이션 코드에 tracing SDK를 넣지 않고도 호출 관계를 추적하려는 기능입니다.

주의:

- 모든 언어/프로토콜/비동기 호출에서 완전한 trace가 항상 보장되는 것은 아닙니다.
- 암호화, 비표준 프로토콜, 짧은 연결에서는 L7 복원 범위가 제한될 수 있습니다.
- 필요하면 OpenTelemetry를 보완 도구로 붙입니다.

## 5. L4/L7 가시성

### 5.1 L4

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
web Pod -> was Service:8080
was Pod -> db Service:3306 또는 5432
```

### 5.2 L7

L7은 HTTP, PostgreSQL, MySQL 같은 애플리케이션 프로토콜 계층입니다.

확인 가능한 것:

- HTTP method
- URL/path
- status code
- request latency
- SQL command
- application protocol

DeepFlow의 L7 관측은 eBPF/packet/protocol 분석 기반입니다. 앱 구조, 프로토콜, 암호화 여부에 따라 복원 수준이 달라질 수 있으므로 실제 traffic으로 확인해야 합니다.

## 6. ClickHouse

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

## 7. Grafana

Grafana는 시각화 도구입니다.

PoC에서 보는 것:

- service map
- namespace별 traffic
- source/destination flow
- HTTP request/error/latency
- DB traffic
- trace view

주의:

- Grafana가 뜬 것만으로 성공이 아닙니다.
- DeepFlow 데이터가 실제로 적재되어야 합니다.
- web-was-db traffic 기준으로 dashboard에서 확인되어야 합니다.

## 8. Terraform

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
- DeepFlow는 먼저 `docs/team/build-guide-deepflow-only.md`의 Helm 명령으로 검증합니다.
- PoC 성공 후 Helm provider/Kubernetes provider로 전환합니다.

권장 전환 순서:

```text
NKS cluster/node group
  -> NKS add-on option
  -> DeepFlow
  -> real web-was-db
  -> real web-was-db
```

## 9. CI/CD

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
  -> validation traffic
  -> DeepFlow visibility check
```

CI/CD에서 반드시 확인할 것:

- image tag 전략
- registry 인증
- kubeconfig/ServiceAccount 권한
- secret 주입 방식
- rollback 기준
- 배포 후 DeepFlow 관측 확인 절차

## 10. web-was-db 검증 의미

현재 검증 workload는 `k8s-3tier-app`의 실제 web-was-db 구조입니다.

```text
external client
  -> web Gateway/Service
  -> was Service
  -> db StatefulSet/Service
```

이 구조로 확인하는 것:

- HTTP L7
- DB TCP 또는 SQL L4/L7
- DeepFlow tagging
- DeepFlow service map
- DeepFlow request log

이 검증이 성공하면 같은 앱을 CI/CD와 Terraform 전환 기준으로 사용합니다.

## 11. 성공/실패 판단

성공:

- DeepFlow Agent가 모든 worker node에서 Ready입니다.
- DeepFlow Grafana에서 대상 namespace의 L4 flow가 보입니다.
- HTTP 또는 DB request log가 보입니다.
- Kubernetes Pod/Service/Namespace tag가 붙습니다.
- 실제 web-was-db 요청이 정상 처리되고 관측됩니다.

보류:

- DeepFlow는 뜨지만 L7 복원이 제한됩니다.
- StorageClass/PVC 문제로 ClickHouse 안정성이 부족합니다.
- Grafana Pod Map에서 tag 반영이 지연됩니다.

실패:

- DeepFlow Agent가 node 권한/kernel 문제로 동작하지 않습니다.
- ClickHouse/Grafana가 PVC 문제로 Ready가 되지 않습니다.
- 운영 표준으로 허용하기 어려운 보안 예외가 필수입니다.

## 12. 공식 문서

- NHN Cloud NKS user guide: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
- DeepFlow deployment overview: https://deepflow.io/docs/ce-install/overview/
- DeepFlow agent advanced config: https://deepflow.io/docs/best-practice/agent-advanced-config/
