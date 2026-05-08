# Legacy ClickHouse/Grafana

이 디렉터리는 이전에 직접 구성하던 ClickHouse/Grafana 경로를 legacy/fallback으로 구분하기 위한 자리입니다.

현재 PoC의 1차 경로는 `infra/observability/deepflow`입니다.

이 디렉터리의 manifest는 DeepFlow chart가 실패하거나 별도 저장소 구성이 필요할 때만 참고합니다.

일반 PoC 실행 흐름에서는 사용하지 않습니다. 정말 필요할 때만 다음처럼 명시적으로 실행합니다.

```powershell
.\scripts\legacy\20-apply-legacy-observability.ps1 -ConfirmLegacy
```
