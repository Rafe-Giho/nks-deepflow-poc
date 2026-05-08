# Legacy Scripts

이 디렉터리의 스크립트는 현재 PoC primary path가 아닙니다.

현재 기준:

```text
Istio Ambient
  -> DeepFlow
  -> DeepFlow ClickHouse/Grafana
  -> sidecarless-smoke
```

사용 금지:

- 일반 PoC 진행
- 새 문서/가이드 작성 시 기본 실행 경로로 참조
- DeepFlow 검증 결과로 해석

실행이 반드시 필요하면 각 스크립트에 `-ConfirmLegacy`를 명시해야 합니다.
