Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root "infra/observability"

kubectl apply -k $path

kubectl -n sidecarless-observability rollout status statefulset/clickhouse --timeout=5m
kubectl -n sidecarless-observability rollout status deploy/grafana --timeout=5m
