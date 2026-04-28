Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root "infra/workloads"

kubectl apply -k $path

kubectl -n sidecarless-demo rollout status deploy/echo-server --timeout=3m
kubectl -n sidecarless-demo create job --from=cronjob/traffic-generator traffic-generator-manual

