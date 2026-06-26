param(
  [string]$SpanRepo = "https://github.com/hongyuanyu/SPAN.git",
  [string]$SpanDir = "external\SPAN"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if (-not (Test-Path $SpanDir)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $SpanDir -Parent) | Out-Null
    git clone $SpanRepo $SpanDir
  }

  python -m pip install -r requirements-w8a12-training.txt
  Push-Location $SpanDir
  try {
    python -m pip install -e .
  } finally {
    Pop-Location
  }

  Write-Host "SETUP_EXTERNAL_SPAN_OK=$SpanDir"
} finally {
  Pop-Location
}
