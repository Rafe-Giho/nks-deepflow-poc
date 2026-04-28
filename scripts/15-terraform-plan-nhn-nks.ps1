param(
  [string]$TerraformDir = ".\infra\terraform\nhn-nks",
  [switch]$SkipInit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw "Terraform CLI is not installed or not in PATH. Install Terraform before running plan."
}

$resolvedDir = Resolve-Path -LiteralPath $TerraformDir

Push-Location $resolvedDir
try {
  terraform fmt -check -recursive

  if (-not $SkipInit) {
    terraform init
  }

  terraform validate
  terraform plan -out nks.tfplan

  Write-Host "`nPlan saved to: $resolvedDir\nks.tfplan"
  Write-Host "Review the plan output. Do not run apply until explicitly approved."
}
finally {
  Pop-Location
}

