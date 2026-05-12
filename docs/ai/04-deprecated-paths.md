# Deleted Historical Paths

이 문서는 현재 PoC 구축 경로에서 제거된 과거 산출물과 재생성 금지 기준을 정리합니다.

## 1. 원칙

- 현재 구축 경로는 `docs/team/01-build-guide.md`에서 선택합니다.
- DeepFlow 단독 경로는 `docs/team/build-guide-deepflow-only.md`를 기준으로 합니다.
- Istio Ambient + Kiali 경로는 `docs/team/build-guide-istio-ambient-kiali.md`를 기준으로 합니다.
- 삭제된 과거 manifest와 PowerShell 실행 래퍼는 사용자가 명시적으로 복원을 요청하지 않는 한 다시 만들지 않습니다.

## 2. 삭제된 범위

| 삭제된 범위 | 현재 대체 기준 | 사유 |
| --- | --- | --- |
| PowerShell 실행 래퍼 | 팀 구축 가이드의 Linux 명령 | 실행 기준 중복과 Windows/Linux 혼동 방지 |
| 직접 ClickHouse/Grafana manifest | DeepFlow Helm chart | DeepFlow chart가 ClickHouse/Grafana를 구성 |
| echo-server sample workload | `infra/apps/smoke` | 현재 검증 기준은 smoke web-was-db |
| `sidecarless-observability` namespace | `deepflow` namespace | 직접 ClickHouse/Grafana 경로 제거 |
| `sidecarless-demo` namespace | `sidecarless-smoke` namespace | echo workload 경로 제거 |
| `sidecarless.network_events` table | DeepFlow ClickHouse schema | 수동 ingestion 가정 제거 |

## 3. 금지되는 사용 사례

- 삭제된 PowerShell wrapper 재생성
- 직접 ClickHouse/Grafana manifest를 기본 구축 경로로 복원
- echo-server sample을 smoke app으로 소개
- DeepFlow 성공 기준 대신 `sidecarless.network_events` count 사용
- `sidecarless-demo` 또는 `sidecarless-observability`를 현재 namespace로 사용

## 4. 필요한 경우

과거 산출물 비교가 꼭 필요하면 새 브랜치나 별도 실험 문서에서 복원 여부를 먼저 결정합니다. 현재 main 경로에는 넣지 않습니다.
