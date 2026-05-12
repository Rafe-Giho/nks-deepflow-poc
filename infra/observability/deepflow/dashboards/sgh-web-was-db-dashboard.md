# DeepFlow Resource Maps by Unit Dashboard

이 문서는 `sgh-web-was-db-dashboard.json` 대시보드의 목적과 패널 해석 기준을 정리한다.

## 목적

이 대시보드는 DeepFlow가 수집한 Kubernetes 트래픽을 여러 리소스 단위로 나누어 보는 검증용 대시보드다.

기본 DeepFlow Pod Map은 여러 종류의 리소스가 한 화면에 섞여 보일 수 있으므로, 이 대시보드는 같은 트래픽을 다음 단위로 분리해 확인한다.

- Workload 단위
- Pod 단위
- Service 단위
- Node 단위

특정 애플리케이션 이름, namespace, pod 이름, DeepFlow 내부 ID를 대시보드에 하드코딩하지 않는다. Grafana 변수로 조회 범위를 선택한다.

## 사용 파일

- Dashboard JSON: `sgh-web-was-db-dashboard.json`
- Dashboard title: `DeepFlow Resource Maps by Unit`
- Dashboard UID: `deepflow-resource-maps-by-unit`

Grafana에서 JSON import로 가져온 뒤, datasource 변수만 현재 환경에 맞게 선택한다.

## Datasource

대시보드는 두 종류의 datasource를 사용한다.

- `deepflow_datasource`: DeepFlow datasource
- `datasource`: DeepFlow ClickHouse datasource

Topo Map 패널은 DeepFlow datasource를 사용하고, 하단 통계/시계열/테이블 패널은 ClickHouse datasource를 사용한다.

## Variables

상단 변수는 모두 동적으로 조회한다. 변수 목록은 DeepFlow ClickHouse의 `flow_tag.*_map` 테이블을 기준으로 만든다.

- `cluster`: Kubernetes cluster
- `namespace`: Kubernetes namespace
- `workload`: Deployment, StatefulSet 등 workload 단위
- `pod`: Pod 단위
- `service`: Service 단위
- `node`: Kubernetes node 단위

기본값은 `All`이며 실제 필터 값은 `__any`다. 먼저 `namespace`를 좁히고, 필요하면 `workload`, `pod`, `service`, `node`를 추가로 선택한다.

변수 조회 기준:

- `cluster`: `flow_tag.pod_cluster_map`
- `namespace`: `flow_tag.pod_ns_map`
- `workload`: `flow_tag.pod_group_map`
- `pod`: `flow_tag.pod_map`
- `service`: `flow_tag.pod_service_map`
- `node`: `flow_tag.pod_node_map`

`namespace`에는 애플리케이션 namespace뿐 아니라 `kube-system`, `deepflow`, `cert-manager`, `nginx-gateway` 같은 시스템 namespace도 표시될 수 있다.

## Topo Panels

### Resource Map - Workload Unit

Workload 기준으로 트래픽 관계를 보여준다.

사용 목적:

- Deployment 또는 StatefulSet 사이의 흐름 확인
- web, was, db 같은 애플리케이션 계층 간 큰 흐름 확인
- Pod가 많아 Pod Map이 복잡할 때 먼저 보는 1차 화면

기준 태그:

- `pod_group_0`
- `pod_group_1`

### Resource Map - Pod Unit

Pod 기준으로 트래픽 관계를 보여준다.

사용 목적:

- 특정 Pod로 트래픽이 몰리는지 확인
- Replica 간 트래픽 분산 상태 확인
- 이름이 보이지 않는 노드가 실제 Pod인지 확인할 때 사용

기준 태그:

- `pod_0`
- `pod_1`

### Resource Map - Service Unit

Service 기준으로 트래픽 관계를 보여준다.

사용 목적:

- Kubernetes Service 또는 VIP 기준의 흐름 확인
- Pod 이름보다 서비스 경로 중심으로 볼 때 사용
- gateway, web service, was service, db service 흐름 확인

기준 태그:

- `auto_service_0`
- `auto_service_1`

### Resource Map - Node Unit

Kubernetes node 기준으로 트래픽 관계를 보여준다.

사용 목적:

- 노드 간 트래픽 경로 확인
- 특정 노드에 트래픽이 집중되는지 확인
- Pod 배치와 노드 간 통신 방향 확인

기준 태그:

- `pod_node_0`
- `pod_node_1`

## Metric Panels

### HTTP Requests

선택한 namespace 범위의 HTTP L7 요청 수를 보여준다.

데이터 기준:

- `flow_log.l7_flow_log`
- `biz_protocol = 'HTTP'`

### L4 Flows

선택한 namespace 범위의 L4 flow 수를 보여준다.

데이터 기준:

- `flow_log.l4_flow_log`

특정 포트로 고정하지 않는다. DB 트래픽도 발생하면 이 값에 포함된다.

### L4 Bytes

선택한 namespace 범위의 L4 송수신 바이트 합계를 보여준다.

데이터 기준:

- `byte_tx + byte_rx`

### L7 Errors

선택한 namespace 범위의 L7 오류 수를 보여준다.

오류 기준:

- `response_status != 0`
- 또는 `response_code >= 500`

### HTTP Requests by Resource

HTTP 요청을 시간대별로 보여준다.

series 기준:

- HTTP method
- request resource
- response code

### L4 Traffic by Port

L4 트래픽을 포트별 시간 흐름으로 보여준다.

series 예시:

- `TCP/80`
- `TCP/8080`
- `TCP/3306`

DB 트래픽이 실제로 발생하면 `TCP/3306` series가 나타난다.

### Top L4 Flow Summary

L4 flow를 client, server, protocol 기준으로 정렬해 보여준다.

사용 목적:

- 어떤 Pod 또는 리소스 간 트래픽이 많은지 확인
- 포트별 주요 통신 경로 확인
- Topo Map에서 두꺼운 선으로 보이는 흐름의 원인 확인

### Recent L7 Logs

최근 L7 요청 로그를 보여준다.

포함 정보:

- 시간
- client pod
- server pod
- protocol
- request method
- request domain
- request resource
- response code
- response time

## 해석 기준

Topo Map의 선은 DeepFlow가 집계한 트래픽 관계를 나타낸다.

- 선이 많으면 해당 범위에서 통신 관계가 많다는 의미다.
- 선이 두꺼우면 상대적으로 트래픽 양이 크다는 의미로 보면 된다.
- Pod Map이 복잡하면 Workload Unit 또는 Service Unit으로 먼저 좁혀서 본다.
- 특정 workload의 세부 분산 상태가 필요하면 Pod Unit으로 전환한다.
- 노드 간 배치 또는 cross-node 흐름이 필요하면 Node Unit을 본다.

## 알려진 한계

DeepFlow `simpleTopo` 패널은 자동 레이아웃 기반이다. 대시보드 JSON에서 각 노드의 좌표를 안정적으로 고정하는 방식은 사용하지 않는다.

따라서 화면을 새로고침하면 노드 위치가 일부 달라질 수 있다. 이 대시보드는 좌표 고정보다는 리소스 단위별 분리로 가시성을 개선하는 방향이다.

DB 전용 포트는 하드코딩하지 않는다. 현재 환경에서 `TCP/3306` 트래픽이 실제로 수집되면 `L4 Traffic by Port`와 `Top L4 Flow Summary`에 표시된다.
