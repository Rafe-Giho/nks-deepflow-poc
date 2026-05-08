param(
  [switch]$ConfirmLegacy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $ConfirmLegacy) {
  throw "Legacy script. Current primary path is scripts/40-deploy-smoke-app.ps1. Re-run with -ConfirmLegacy only when testing the old echo workload."
}

$root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$path = Join-Path $root "infra/legacy/workloads"

kubectl apply -k $path

kubectl -n sidecarless-demo rollout status deploy/echo-server --timeout=3m
$jobName = "traffic-generator-manual-$(Get-Date -Format 'yyyyMMddHHmmss')"
kubectl -n sidecarless-demo create job --from=cronjob/traffic-generator $jobName
