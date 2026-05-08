param(
  [string]$Namespace = "deepflow",
  [string]$ReleaseName = "deepflow"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Helm release"
helm status $ReleaseName -n $Namespace

Write-Host "`nDeepFlow workloads"
kubectl -n $Namespace get daemonset,deploy,statefulset,pods,svc,pvc -o wide

Write-Host "`nPod readiness"
$pods = kubectl -n $Namespace get pods -o json | ConvertFrom-Json
if ($pods.items.Count -eq 0) {
  throw "No DeepFlow pods found in namespace $Namespace"
}

$notReady = @()
foreach ($pod in $pods.items) {
  foreach ($condition in $pod.status.conditions) {
    if ($condition.type -eq "Ready" -and $condition.status -ne "True") {
      $notReady += $pod.metadata.name
    }
  }
}

if ($notReady.Count -gt 0) {
  throw "DeepFlow pods are not ready: $($notReady -join ', ')"
}

Write-Host "All DeepFlow pods are Ready"

Write-Host "`nGrafana access"
Write-Host "kubectl -n $Namespace port-forward svc/deepflow-grafana 3000:80"
Write-Host "Default auth from DeepFlow docs: admin:deepflow"
