# PoC #1 설계안 및 방향성

## 1. 우선순위 결론

현재 PoC의 1순위 설계는 두 경로를 분리 검증하는 것입니다. 하나는 **NHN Cloud NKS + DeepFlow + ClickHouse + Grafana**, 다른 하나는 **NHN Cloud NKS + Istio Ambient + Kiali**입니다. DeepFlow는 Istio Ambient + Kiali 뒤에 선택 확장으로 추가합니다.

이전 Cilium/Hubble 기준은 현 목표에서 제외하고, 필요한 경우 비교 또는 참고 후보로만 둡니다.

## 2. 설계안 평가 기준

| 기준 | 설명 |
| --- | --- |
| NKS 적합성 | NHN Cloud NKS에서 실제 설치/운영 가능한지 |
| Sidecarless 정합성 | 애플리케이션 Pod에 Envoy sidecar가 없는지 |
| L4 가시성 | Pod/Service/Namespace 기준 flow를 볼 수 있는지 |
| L7 가시성 | HTTP, SQL 등 request 단위 로그/trace를 볼 수 있는지 |
| 운영 단순성 | 설치, 업그레이드, 장애 대응이 가능한지 |
| Terraform 전환성 | 마지막 단계에서 IaC로 재현 가능한지 |
| CI/CD 확장성 | 실제 web-was-db 배포 파이프라인으로 확장 가능한지 |

## 3. 1순위. DeepFlow 단독

구성:

```text
NHN Cloud NKS
  -> DeepFlow
  -> DeepFlow ClickHouse
  -> DeepFlow Grafana
```

장점:

- Istio 없이 DeepFlow 자체의 NKS 적합성을 먼저 확인합니다.
- eBPF Agent, ClickHouse, Grafana 리스크를 mesh 리스크와 분리합니다.
- DeepFlow가 L4 flow, L7 request log, AutoTracing을 한 경로로 제공합니다.
- ClickHouse/Grafana를 DeepFlow stack 안에서 일관되게 운영할 수 있습니다.

단점/리스크:

- DeepFlow eBPF 수집 권한이 NKS 보안 정책과 맞아야 합니다.
- DeepFlow chart가 구성하는 ClickHouse/Grafana 운영 리소스 요구량을 확인해야 합니다.

채택 판단:

- DeepFlow 관측 도구 검증 경로로 채택합니다.

## 4. 2순위. Istio Ambient + Kiali

Istio Ambient를 구성하고 Kiali로 mesh 상태와 topology를 확인하는 방안입니다.

장점:

- sidecar 없이 ztunnel/waypoint mesh를 확인할 수 있습니다.
- Kiali에서 ambient namespace, waypoint, service graph를 확인할 수 있습니다.
- mesh 설정 오류와 telemetry 상태를 빠르게 볼 수 있습니다.

단점:

- Prometheus가 필요합니다.
- Istio 밖의 traffic이나 node-level eBPF flow는 직접 보지 않습니다.

채택 판단:

- Istio Ambient mesh 검증 경로로 채택합니다.

## 5. 3순위. Istio Ambient + OpenTelemetry + DeepFlow 보조

애플리케이션 trace는 OpenTelemetry로 보완하고, DeepFlow는 네트워크/인프라 trace를 맡기는 방안입니다.

장점:

- cross-thread/asynchronous trace 한계를 보완할 수 있습니다.
- 실제 web-was-db가 이미 OTel을 지원하면 trace 품질이 좋아집니다.

단점:

- sidecarless는 유지되지만 코드/SDK 또는 agent 설정 부담이 늘어납니다.
- 현재 1차 목표보다 범위가 커집니다.

채택 판단:

- DeepFlow만으로 L7/trace가 부족할 때 2차 보완책으로 둡니다.

## 6. 4순위. Istio Sidecar baseline + DeepFlow 비교

Ambient와 기존 sidecar 방식의 차이를 비교하기 위한 baseline입니다.

장점:

- CPU/memory/container 수/latency 비교 근거를 만들 수 있습니다.
- 보고서 설득력이 좋아집니다.

단점:

- 현재 목표는 sidecarless이므로 주 경로가 아닙니다.
- 별도 namespace와 injection 정책이 필요합니다.

채택 판단:

- 성능/운영 비교가 필요할 때만 추가합니다.

## 7. 5순위. Cilium/Hubble 재검토

이전 검토 축이었던 Cilium/Hubble을 별도 비교 대상으로 두는 방안입니다.

장점:

- eBPF flow observability 기준선으로 활용할 수 있습니다.

단점:

- 현재 목표와 직접 맞지 않습니다.
- NKS 기본 CNI/관리형 add-on과 충돌 가능성이 있습니다.

채택 판단:

- 현재 PoC에서는 제외합니다. 필요하면 별도 실험으로 분리합니다.

## 8. 권장 진행 순서

```text
NKS preflight
  -> Istio Ambient
  -> DeepFlow
  -> smoke web-was-db
  -> DeepFlow visibility check
  -> real web-was-db
  -> CI/CD
  -> Terraform
```

## 9. 최종 산출물

- NKS 조건 검증 로그
- Istio Ambient 설치/검증 절차
- DeepFlow 설치/검증 절차
- smoke web-was-db manifest
- L4/L7 가시성 검증 결과
- 실제 web-was-db 배포 가이드
- CI/CD 설계
- Terraform 전환 설계
