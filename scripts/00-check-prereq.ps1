Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$tools = @("kubectl", "terraform")
$missing = @()

foreach ($tool in $tools) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    $missing += $tool
  }
}

if ($missing.Count -gt 0) {
  throw "Missing required tools: $($missing -join ', ')"
}

Write-Host "kubectl:"
kubectl version --client

Write-Host "`nterraform:"
terraform version

Write-Host "`ncurrent context:"
kubectl config current-context

Write-Host "`ncluster nodes:"
kubectl get nodes -o wide
