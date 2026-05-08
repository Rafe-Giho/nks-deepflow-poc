param(
  [string]$Namespace = "sidecarless-smoke",
  [switch]$EnableWaypoint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$path = Join-Path $root "infra/apps/smoke"

Write-Host "Applying smoke web-was-db workload"
kubectl apply -k $path

Write-Host "Waiting for smoke deployments"
kubectl -n $Namespace rollout status deploy/smoke-was --timeout=3m
kubectl -n $Namespace rollout status deploy/smoke-db --timeout=3m

if ($EnableWaypoint) {
  Write-Host "Applying Istio waypoint for L7 validation"
  istioctl waypoint apply -n $Namespace --enroll-namespace --for service
}

$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$httpJob = "http-traffic-$timestamp"
$sqlJob = "sql-traffic-$timestamp"

Write-Host "Creating traffic jobs"
kubectl -n $Namespace create job --from=cronjob/http-traffic $httpJob
kubectl -n $Namespace create job --from=cronjob/sql-traffic $sqlJob

Write-Host "Waiting for traffic jobs"
kubectl -n $Namespace wait --for=condition=complete "job/$httpJob" --timeout=180s
kubectl -n $Namespace wait --for=condition=complete "job/$sqlJob" --timeout=180s

Write-Host "Smoke workload status"
kubectl -n $Namespace get pods,svc,jobs,cronjobs -o wide
