# PoC #1 설계안 및 방향성

## 1. 우선순위 결론

현재 PoC의 1순위 설계는 **NHN Cloud NKS + Istio Ambient + DeepFlow + ClickHouse + Grafana**입니다.

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

## 3. 1순위. Istio Ambient + DeepFlow

구성:

```text
NHN Cloud NKS
  -> Istio Ambient
  -> DeepFlow
  -> DeepFlow ClickHouse
  -> DeepFlow Grafana
```

장점:

- 사용자가 명시한 목표와 직접 일치합니다.
- 애플리케이션 Pod에 sidecar를 넣지 않습니다.
- Ambient의 ztunnel로 L4 mesh를 구성할 수 있습니다.
- waypoint를 추가하면 L7 정책/라우팅 검증이 가능합니다.
- DeepFlow가 L4 flow, L7 request log, AutoTracing을 한 경로로 제공합니다.
- ClickHouse/Grafana를 DeepFlow stack 안에서 일관되게 운영할 수 있습니다.

단점/리스크:

- DeepFlow eBPF 수집 권한이 NKS 보안 정책과 맞아야 합니다.
- Ambient mTLS/HBONE 경로에서 DeepFlow L7 가시성 범위는 실제 검증이 필요합니다.
- DeepFlow chart가 구성하는 ClickHouse/Grafana 운영 리소스 요구량을 확인해야 합니다.

채택 판단:

- 현재 PoC의 primary path로 채택합니다.

## 4. 2순위. Istio Ambient + DeepFlow + 별도 Grafana

DeepFlow는 수집/저장에 사용하고, 기존 사내 Grafana나 별도 Grafana를 붙이는 방안입니다.

장점:

- 조직 표준 Grafana가 있을 경우 통합이 쉽습니다.
- dashboard 권한/SSO를 기존 체계와 맞추기 좋습니다.

단점:

- DeepFlow 기본 dashboard와 별도 dashboard가 중복될 수 있습니다.
- ClickHouse schema와 datasource 연결을 별도로 관리해야 합니다.

채택 판단:

- PoC 성공 후 운영 표준화 단계에서 검토합니다.

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
- Istio Ambient 설치/검증 스크립트
- DeepFlow 설치/검증 스크립트
- smoke web-was-db manifest
- L4/L7 가시성 검증 결과
- 실제 web-was-db 배포 가이드
- CI/CD 설계
- Terraform 전환 설계
