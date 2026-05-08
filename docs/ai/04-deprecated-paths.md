# Deprecated Paths

이 문서는 현재 PoC 구축 경로에서 제외된 파일과 디렉터리를 명확히 구분합니다.

## 1. 원칙

아래 경로는 보존용입니다.

- 기본 실행 흐름에 포함하지 않습니다.
- 새 문서에서 현재 구축 경로로 소개하지 않습니다.
- AI가 작업 기준으로 삼지 않습니다.
- 사용자가 명시적으로 legacy 검증을 요청한 경우에만 사용합니다.

## 2. Deleted Script Paths

Windows PowerShell 실행 래퍼는 혼동을 줄이기 위해 저장소에서 제거했습니다. 아래 경로는 다시 만들지 않습니다.

| 삭제된 범위 | 대체 기준 | 사유 |
| --- | --- | --- |
| PowerShell 실행 래퍼 | `docs/team/01-build-guide.md` | Linux 구축 가이드와 중복되어 실행 기준을 흐림 |
| legacy PowerShell 실행 래퍼 | `docs/ai/04-deprecated-paths.md` | legacy 실행 경로가 primary PoC와 혼동됨 |

## 3. Deprecated Manifests

| 경로 | 대체 경로 | 사유 |
| --- | --- | --- |
| `infra/observability/legacy-clickhouse-grafana` | `infra/observability/deepflow` | DeepFlow chart가 ClickHouse/Grafana를 포함 |
| `infra/legacy/workloads` | `infra/apps/smoke` | echo-server sample은 web-was-db 흐름이 아님 |

## 4. Deprecated Namespaces

| 이름 | 대체 | 사유 |
| --- | --- | --- |
| `sidecarless-observability` | `deepflow` | 직접 ClickHouse/Grafana legacy namespace |
| `sidecarless-demo` | `sidecarless-smoke` | echo workload legacy namespace |

## 5. Deprecated Data Model

| 이름 | 대체 | 사유 |
| --- | --- | --- |
| `sidecarless.network_events` | DeepFlow ClickHouse schema | 이전 수동 ingestion 가정의 테이블 |

현재 PoC는 DeepFlow가 생성/관리하는 ClickHouse schema와 Grafana dashboard를 기준으로 검증합니다.

## 6. 허용되는 사용 사례

legacy 경로는 다음 경우에만 사용합니다.

- 과거 산출물 비교
- direct ClickHouse/Grafana fallback 실험
- 문서 마이그레이션 검토
- 사용자가 명시적으로 legacy 실행을 요청한 경우

실행이 필요하면 `docs/team/01-build-guide.md`에서 경로를 선택한 뒤 해당 분리 가이드의 Linux 명령을 기준으로 수동 비교 실험을 작성합니다.

## 7. 금지되는 사용 사례

- 새 PoC 실행 순서에 legacy script 추가
- Windows PowerShell 실행 래퍼 재생성
- DeepFlow 성공 기준 대신 `sidecarless.network_events` count 사용
- `infra/legacy/workloads`를 smoke app으로 소개
- `sidecarless-demo`를 primary namespace로 사용
