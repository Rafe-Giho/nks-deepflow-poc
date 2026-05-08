param(
  [string]$TerraformDir = ".\infra\terraform\nhn-nks",
  [string]$TerraformExe = "",
  [switch]$SkipInit
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

  throw "Terraform CLI is not installed or not in PATH. Install Terraform or pass -TerraformExe."
}

$resolvedTerraformExe = Resolve-TerraformExe -ExplicitPath $TerraformExe
$resolvedDir = Resolve-Path -LiteralPath $TerraformDir

Push-Location $resolvedDir
try {
  & $resolvedTerraformExe fmt -check -recursive

  if (-not $SkipInit) {
    & $resolvedTerraformExe init -input=false
  }

  & $resolvedTerraformExe validate
  & $resolvedTerraformExe plan -input=false

  Write-Host "`nReview the plan output. Do not run apply until explicitly approved."
}
finally {
  Pop-Location
}
