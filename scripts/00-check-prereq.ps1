param(
  [string]$TerraformExe = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-TerraformExe {
  param([string]$ExplicitPath)

  if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
    if (-not (Test-Path -LiteralPath $ExplicitPath)) {
      throw "Terraform executable was not found: $ExplicitPath"
    }
    return (Resolve-Path -LiteralPath $ExplicitPath).Path
  }

  $terraformCommand = Get-Command terraform -ErrorAction SilentlyContinue
  if ($terraformCommand) {
    return $terraformCommand.Source
  }

  $defaultWindowsPath = "C:\terraform\terraform.exe"
  if (Test-Path -LiteralPath $defaultWindowsPath) {
    return $defaultWindowsPath
  }

  return $null
}

$tools = @("kubectl", "helm", "istioctl")
$missing = @()

foreach ($tool in $tools) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    $missing += $tool
  }
}

$resolvedTerraformExe = Resolve-TerraformExe -ExplicitPath $TerraformExe
if (-not $resolvedTerraformExe) {
  $missing += "terraform"
}

if ($missing.Count -gt 0) {
  throw "Missing required tools: $($missing -join ', ')"
}

Write-Host "kubectl:"
kubectl version --client

Write-Host "`nhelm:"
helm version

Write-Host "`nistioctl:"
istioctl version --remote=false

Write-Host "`nterraform:"
& $resolvedTerraformExe version

Write-Host "`ncurrent context:"
kubectl config current-context

Write-Host "`ncluster nodes:"
kubectl get nodes -o wide
