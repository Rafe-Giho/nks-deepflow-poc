# Deprecated Paths

이 문서는 현재 PoC primary path에서 제외된 파일과 디렉터리를 명확히 구분합니다.

## 1. 원칙

아래 경로는 보존용입니다.

- 기본 실행 흐름에 포함하지 않습니다.
- 새 문서에서 primary path로 소개하지 않습니다.
- AI가 작업 기준으로 삼지 않습니다.
- 사용자가 명시적으로 legacy 검증을 요청한 경우에만 사용합니다.

## 2. Deprecated Scripts

| 경로 | 대체 경로 | 사유 |
| --- | --- | --- |
| `scripts/legacy/20-apply-legacy-observability.ps1` | `scripts/30-install-deepflow.ps1` | 직접 ClickHouse/Grafana 배포는 primary가 아님 |
| `scripts/legacy/30-deploy-legacy-echo-workload.ps1` | `scripts/40-deploy-smoke-app.ps1` | echo workload는 smoke web-was-db를 대체하지 못함 |
| `scripts/legacy/40-legacy-smoke-test.ps1` | `scripts/50-verify-poc-visibility.ps1` | `sidecarless.network_events` 기준 검증은 DeepFlow 기준이 아님 |

legacy 스크립트는 실수 방지를 위해 `-ConfirmLegacy` 없이는 실행되지 않습니다.

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

실행 예:

```powershell
.\scripts\legacy\20-apply-legacy-observability.ps1 -ConfirmLegacy
```

## 7. 금지되는 사용 사례

- 새 PoC 실행 순서에 legacy script 추가
- DeepFlow 성공 기준 대신 `sidecarless.network_events` count 사용
- `infra/legacy/workloads`를 smoke app으로 소개
- `sidecarless-demo`를 primary namespace로 사용
