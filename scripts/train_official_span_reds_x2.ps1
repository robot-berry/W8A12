param(
  [string]$RedsRoot = "",
  [switch]$SkipConfigure
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  $env:KMP_DUPLICATE_LIB_OK = "TRUE"
  $spanRoot = Join-Path $root "external\SPAN"
  if (-not (Test-Path $spanRoot)) {
    throw "Missing external\SPAN. Run scripts/setup_external_span.ps1 first."
  }
  $env:PYTHONPATH = "$spanRoot;$env:PYTHONPATH"

  if (-not $SkipConfigure) {
    if ($RedsRoot -eq "") {
      throw "Pass -RedsRoot, or run scripts/configure_span_training.ps1 first and use -SkipConfigure."
    }
    powershell -ExecutionPolicy Bypass -File scripts\configure_span_training.ps1 -RedsRoot $RedsRoot
  }

  Push-Location $spanRoot
  try {
    python basicsr/train.py `
      -opt options/train/SPAN/train_SPAN_REDS_x2.yml `
      --launcher none
  } finally {
    Pop-Location
  }
} finally {
  Pop-Location
}
