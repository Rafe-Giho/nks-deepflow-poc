Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Istio CLI version"
istioctl version

Write-Host "`nGateway API CRD"
kubectl get crd gateways.gateway.networking.k8s.io

Write-Host "`nIstio system workloads"
kubectl -n istio-system get deploy,daemonset,pods,svc -o wide

Write-Host "`nAmbient namespace labels"
kubectl get ns -L istio.io/dataplane-mode,istio.io/use-waypoint

Write-Host "`nWaypoints"
try {
  istioctl waypoint list -A
} catch {
  Write-Host "No waypoint information available yet"
}

Write-Host "`nIstio analyze"
istioctl analyze
