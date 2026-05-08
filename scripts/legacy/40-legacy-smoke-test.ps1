param(
  [switch]$ConfirmLegacy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $ConfirmLegacy) {
  throw "Legacy script. Current primary path is scripts/50-verify-poc-visibility.ps1. Re-run with -ConfirmLegacy only when testing the old direct ClickHouse/Grafana stack."
}

Write-Host "Legacy smoke test path. Current primary path is scripts/50-verify-poc-visibility.ps1."

Write-Host "Calico/NKS system pods"
kubectl -n kube-system get pods -o wide | Select-String -Pattern "calico|typha|coredns" -CaseSensitive:$false

Write-Host "`nCalico Felix signal"
$calicoPods = @(kubectl -n kube-system get pods -o name | Where-Object { $_ -match "calico" })
foreach ($pod in $calicoPods) {
  Write-Host $pod
  kubectl -n kube-system logs $pod --tail=80 --all-containers |
    Select-String -Pattern "felix|bpf|kube-proxy" -CaseSensitive:$false |
    Select-Object -First 10
}

Write-Host "`nkube-proxy check"
$kubeProxy = kubectl -n kube-system get daemonset kube-proxy --ignore-not-found
if ([string]::IsNullOrWhiteSpace($kubeProxy)) {
  Write-Host "kube-proxy DaemonSet not found. This is expected for Calico-eBPF mode."
} else {
  Write-Host $kubeProxy
}

Write-Host "`nObservability stack"
kubectl -n sidecarless-observability get pods,svc -o wide

Write-Host "`nDemo workload"
kubectl -n sidecarless-demo get pods,svc,jobs,cronjobs -o wide

Write-Host "`nClickHouse network event count"
kubectl -n sidecarless-observability exec statefulset/clickhouse -- clickhouse-client `
  --query "SELECT count() AS events FROM sidecarless.network_events"

Write-Host "`nGrafana local access command:"
Write-Host "kubectl -n sidecarless-observability port-forward svc/grafana 3000:3000"
