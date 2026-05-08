param(
  [string]$SmokeNamespace = "sidecarless-smoke",
  [string]$DeepFlowNamespace = "deepflow"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Ambient namespace labels"
kubectl get ns $SmokeNamespace -L istio.io/dataplane-mode,istio.io/use-waypoint

Write-Host "`nSmoke workload"
kubectl -n $SmokeNamespace get pods,svc,jobs,cronjobs -o wide

Write-Host "`nChecking sidecar absence"
$pods = kubectl -n $SmokeNamespace get pods -o json | ConvertFrom-Json
$sidecarPods = @()
foreach ($pod in $pods.items) {
  foreach ($container in $pod.spec.containers) {
    if ($container.name -eq "istio-proxy") {
      $sidecarPods += $pod.metadata.name
    }
  }
}

if ($sidecarPods.Count -gt 0) {
  throw "Unexpected istio-proxy sidecar found: $($sidecarPods -join ', ')"
}

Write-Host "No istio-proxy sidecars found in $SmokeNamespace"

Write-Host "`nIstio Ambient components"
kubectl -n istio-system get deploy,daemonset,pods -o wide

Write-Host "`nIstio waypoints"
try {
  istioctl waypoint list -n $SmokeNamespace
} catch {
  Write-Host "No waypoint information available"
}

Write-Host "`nDeepFlow status"
kubectl -n $DeepFlowNamespace get daemonset,deploy,statefulset,pods,svc -o wide

Write-Host "`nManual Grafana access"
Write-Host "kubectl -n $DeepFlowNamespace port-forward svc/deepflow-grafana 3000:80"
Write-Host "Then inspect DeepFlow dashboards for:"
Write-Host "- source/destination namespace: $SmokeNamespace"
Write-Host "- HTTP traffic to service: smoke-was"
Write-Host "- PostgreSQL traffic to service: smoke-db"
