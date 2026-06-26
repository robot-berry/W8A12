param(
  [string]$QuantPlan = "runs\reds_span_quant_plan\reds_span_x4_f48_w8a12_reds_val4\span_w8a12_quant_plan.json",
  [string]$OutputDir = "rtl\generated\reds_span_x4_f48_w8a12"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if (-not (Test-Path $QuantPlan)) {
    throw "Quant plan not found: $QuantPlan"
  }

  python tools\export_span_quant_plan_to_rtl.py `
    --quant-plan $QuantPlan `
    --out-dir $OutputDir `
    --copy-plan
  if ($LASTEXITCODE -ne 0) {
    throw "export_span_quant_plan_to_rtl.py failed with exit code $LASTEXITCODE"
  }

  $manifest = Join-Path $OutputDir "span_w8a12_rtl_manifest.json"
  python tools\check_span_w8a12_rtl_export.py --rtl-manifest $manifest
  if ($LASTEXITCODE -ne 0) {
    throw "check_span_w8a12_rtl_export.py failed with exit code $LASTEXITCODE"
  }

  Write-Host "PASS export_reds_span_w8a12_to_rtl"
  Write-Host "RTL_MANIFEST=$manifest"
  Write-Host "RTL_HEADER=$(Join-Path $OutputDir 'span_w8a12_layers.vh')"
} finally {
  Pop-Location
}
