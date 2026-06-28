param(
  [string]$Checkpoint = "runs\official_span\official_SPAN_REDS_x2_f48\models\net_g_300000.pth",
  [string]$OfficialManifest = "rtl\generated\official_span_x2\official_span_manifest.json",
  [string]$CalibrationInput = "G:\REDS\val_sharp",
  [int]$CalibrationWidth = 640,
  [int]$CalibrationHeight = 360,
  [int]$MaxImages = 8,
  [string]$CalibrationOut = "runs\reds_span_calibration\reds_val8_x2_640x360_a12\activation_scales.json",
  [string]$QuantOutDir = "runs\reds_span_quant_plan\reds_span_x2_f48_w8a12",
  [string]$RtlOutDir = "rtl\generated\reds_span_x2_f48_w8a12"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
  if (-not (Test-Path $Checkpoint)) { throw "Checkpoint not found: $Checkpoint" }
  if (-not (Test-Path $OfficialManifest)) { throw "Official manifest not found: $OfficialManifest" }
  if (-not (Test-Path $CalibrationInput)) { throw "Calibration input not found: $CalibrationInput" }

  python tools\calibrate_span_activation_scales.py `
    --manifest $OfficialManifest `
    --checkpoint $Checkpoint `
    --input $CalibrationInput `
    --width $CalibrationWidth `
    --height $CalibrationHeight `
    --out $CalibrationOut `
    --max-images $MaxImages `
    --activation-bits 12
  if ($LASTEXITCODE -ne 0) { throw "calibrate_span_activation_scales.py failed with exit code $LASTEXITCODE" }

  $QuantPlan = Join-Path $QuantOutDir "span_w8a12_quant_plan.json"
  python tools\export_span_w8a12_quant_plan.py `
    --manifest $OfficialManifest `
    --checkpoint $Checkpoint `
    --activation-scales $CalibrationOut `
    --out-dir $QuantOutDir `
    --activation-bits 12 `
    --weight-bits 8 `
    --device cpu
  if ($LASTEXITCODE -ne 0) { throw "export_span_w8a12_quant_plan.py failed with exit code $LASTEXITCODE" }

  python tools\export_span_quant_plan_to_rtl.py `
    --quant-plan $QuantPlan `
    --out-dir $RtlOutDir `
    --tag REDS_SPAN_X2_W8A12 `
    --copy-plan
  if ($LASTEXITCODE -ne 0) { throw "export_span_quant_plan_to_rtl.py failed with exit code $LASTEXITCODE" }

  python tools\export_span_w8a12_postprocess_to_rtl.py `
    --quant-plan $QuantPlan `
    --out-dir (Join-Path $RtlOutDir "postprocess")
  if ($LASTEXITCODE -ne 0) { throw "export_span_w8a12_postprocess_to_rtl.py failed with exit code $LASTEXITCODE" }

  $RtlManifest = Join-Path $RtlOutDir "span_w8a12_rtl_manifest.json"
  python tools\check_span_w8a12_rtl_export.py --rtl-manifest $RtlManifest
  if ($LASTEXITCODE -ne 0) { throw "check_span_w8a12_rtl_export.py failed with exit code $LASTEXITCODE" }

  python W8A12_3lane\tools\check_x2_w8a12_export.py `
    --rtl-manifest $RtlManifest `
    --postprocess-manifest (Join-Path $RtlOutDir "postprocess\span_w8a12_postprocess_manifest.json") `
    --quant-plan $QuantPlan
  if ($LASTEXITCODE -ne 0) { throw "check_x2_w8a12_export.py failed with exit code $LASTEXITCODE" }

  Write-Host "PASS export_x2_w8a12_to_rtl"
  Write-Host "QUANT_PLAN=$QuantPlan"
  Write-Host "RTL_MANIFEST=$RtlManifest"
  Write-Host "POSTPROCESS_MANIFEST=$(Join-Path $RtlOutDir 'postprocess\span_w8a12_postprocess_manifest.json')"
} finally {
  Pop-Location
}
