param(
  [string]$IstioOperatorFile = ".\infra\mesh\istio-ambient\istio-operator.yaml",
  [string]$GatewayApiVersion = "v1.4.0",
  [switch]$SkipGatewayApi
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot

function Resolve-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return (Resolve-Path -LiteralPath $Path).Path
  }

  return (Resolve-Path -LiteralPath (Join-Path $root $Path)).Path
}

if (-not $SkipGatewayApi) {
  Write-Host "Checking Gateway API CRDs"
  $gatewayCrd = kubectl get crd gateways.gateway.networking.k8s.io --ignore-not-found
  if ([string]::IsNullOrWhiteSpace($gatewayCrd)) {
    $gatewayApiUrl = "https://github.com/kubernetes-sigs/gateway-api/releases/download/$GatewayApiVersion/experimental-install.yaml"
    Write-Host "Installing Gateway API CRDs from $gatewayApiUrl"
    kubectl apply --server-side -f $gatewayApiUrl
  } else {
    Write-Host "Gateway API CRD already exists"
  }
}

$operatorPath = Resolve-RepoPath -Path $IstioOperatorFile

Write-Host "Installing Istio Ambient from $operatorPath"
istioctl install -f $operatorPath --skip-confirmation

Write-Host "Waiting for Istio components"
kubectl -n istio-system rollout status deploy/istiod --timeout=5m
kubectl -n istio-system rollout status daemonset/istio-cni-node --timeout=5m
kubectl -n istio-system rollout status daemonset/ztunnel --timeout=5m

Write-Host "Running istioctl analyze"
istioctl analyze
