param(
  [string]$Namespace = "deepflow",
  [string]$ReleaseName = "deepflow",
  [string]$ChartVersion = "6.6.018",
  [string]$ValuesFile = ".\infra\observability\deepflow\values\poc-values.yaml",
  [string]$StorageClass = "",
  [int]$Replicas = 1
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

$valuesPath = Resolve-RepoPath -Path $ValuesFile

Write-Host "Adding DeepFlow Helm repo"
helm repo add deepflow https://deepflowio.github.io/deepflow --force-update
helm repo update deepflow

$helmArgs = @(
  "upgrade",
  "--install",
  $ReleaseName,
  "deepflow/deepflow",
  "-n",
  $Namespace,
  "--version",
  $ChartVersion,
  "--create-namespace",
  "-f",
  $valuesPath,
  "--set",
  "global.replicas=$Replicas"
)

if (-not [string]::IsNullOrWhiteSpace($StorageClass)) {
  $helmArgs += @("--set", "global.storageClass=$StorageClass")
}

Write-Host "Installing DeepFlow $ChartVersion"
& helm @helmArgs

Write-Host "DeepFlow resources"
kubectl -n $Namespace get pods,svc,pvc -o wide
