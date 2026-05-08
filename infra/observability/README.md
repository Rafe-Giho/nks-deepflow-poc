# Observability

현재 PoC의 1차 관측 경로는 `deepflow`입니다.

```text
DeepFlow
  -> deepflow-agent
  -> deepflow-server
  -> ClickHouse
  -> Grafana
```

이 디렉터리 루트에는 primary manifest를 두지 않습니다.

- `deepflow/`: 현재 primary 관측 경로
- `legacy-clickhouse-grafana/`: 이전 직접 ClickHouse/Grafana fallback 경로
