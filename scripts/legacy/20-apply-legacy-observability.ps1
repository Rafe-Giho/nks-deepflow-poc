param(
  [switch]$ConfirmLegacy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $ConfirmLegacy) {
  throw "Legacy script. Current primary path is scripts/30-install-deepflow.ps1. Re-run with -ConfirmLegacy only when testing the old direct ClickHouse/Grafana stack."
}

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$path = Join-Path $root "infra/observability/legacy-clickhouse-grafana"

Write-Host "Legacy observability path. Current primary path is scripts/30-install-deepflow.ps1."

kubectl apply -k $path

kubectl -n sidecarless-observability rollout status statefulset/clickhouse --timeout=5m
kubectl -n sidecarless-observability rollout status deploy/grafana --timeout=5m
