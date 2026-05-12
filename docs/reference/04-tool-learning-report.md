# 도구 학습 보고서

## 1. 요약

이 PoC에서 학습해야 할 핵심 도구는 NHN Cloud NKS, Calico/Felix, DeepFlow, ClickHouse, Grafana, Terraform입니다.

목표는 DeepFlow가 NKS에서 Pod/Service/Namespace 기준 L4/L7 관측 데이터를 수집하고, ClickHouse/Grafana로 확인 가능한지 검증하는 것입니다.

## 2. NHN Cloud NKS

NKS는 관리형 Kubernetes입니다.

확인해야 할 것:

- Kubernetes version
- worker node OS/kernel
- node flavor와 resource 여유
- Calico/Felix 상태
- `csi-cinder` add-on
- kubeconfig와 권한

NKS에서 중요한 이유:

- DeepFlow Agent는 worker node의 kernel/eBPF 기능에 의존합니다.
- ClickHouse/MySQL은 PVC가 필요합니다.
- 네트워크와 보안 정책이 flow 수집 범위에 영향을 줄 수 있습니다.

## 3. Calico/Felix

Calico는 NKS의 Pod 네트워크 기반입니다. Felix는 각 node에서 endpoint, routing, policy 상태를 반영합니다.

PoC에서 확인할 것:

- Calico/Felix Pod Running
- CoreDNS 정상
- Pod/Service 통신 정상
- network policy가 앱 통신을 막지 않는지

Calico/Felix 자체가 관측 도구는 아니지만, DeepFlow가 수집하는 traffic의 기반 네트워크입니다.

## 4. DeepFlow

DeepFlow는 eBPF 기반 observability 플랫폼입니다.

구성:

- Agent: 각 node에서 traffic과 protocol 정보를 수집
- Server: agent 관리와 데이터 처리
- ClickHouse: flow/log/metric 저장
- Grafana: dashboard 제공

핵심 기능:

- AutoTagging: Kubernetes metadata 자동 연결
- AutoMetrics: request/error/latency/throughput metric 생성
- AutoTracing: 호출 관계 추적 보조
- L4/L7 log: TCP/HTTP/DB 등 traffic 분석

주의:

- Agent 권한과 kernel 호환성이 필요합니다.
- L7 복원은 프로토콜/암호화/traffic 형태에 따라 달라질 수 있습니다.
- 이름 없는 노드는 metadata sync 지연 또는 tag dictionary 누락으로 발생할 수 있습니다.

## 5. ClickHouse

ClickHouse는 DeepFlow 관측 데이터의 저장소입니다.

확인할 것:

- PVC Bound
- row 증가 여부
- `flow_tag` dictionary table
- `flow_log` L4/L7 table
- `flow_metrics` metric table

PoC에서는 ClickHouse에 직접 query해 Grafana 결과를 검증할 수 있어야 합니다.

## 6. Grafana

Grafana는 DeepFlow dashboard를 보여주는 UI입니다.

확인할 것:

- namespace/service/pod filter
- Pod Map 또는 Service Map
- HTTP request/error/latency
- L4 flow
- L7 request log

Grafana는 결과 화면이고, 실제 수집 여부는 ClickHouse query와 함께 확인해야 합니다.

## 7. Terraform

Terraform은 검증된 구성을 코드로 전환하기 위한 도구입니다.

현재 원칙:

- NKS 리소스는 plan-only
- apply는 명시 승인 전 금지
- `terraform.tfvars`, tfstate, kubeconfig는 커밋 금지
- DeepFlow Helm release는 PoC 성공 후 module화

## 8. 결론

현재 프로젝트는 DeepFlow 단독 관측 경로를 기준으로 진행합니다.

성공하면 다음을 얻습니다.

- NKS에서 DeepFlow 설치 가능 여부
- web-was-db traffic의 L4/L7 관측 가능 범위
- ClickHouse/Grafana 기반 검증 절차
- CI/CD와 Terraform 전환 기준

## 9. 공식 문서

- NHN Cloud NKS user guide: https://docs.nhncloud.com/ko/Container/NKS/ko/user-guide/
- DeepFlow single K8s install: https://deepflow.io/docs/ce-install/single-k8s/
- DeepFlow deployment overview: https://deepflow.io/docs/ce-install/overview/
- DeepFlow agent advanced config: https://deepflow.io/docs/best-practice/agent-advanced-config/
