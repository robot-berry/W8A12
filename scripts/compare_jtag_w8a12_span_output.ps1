param(
  [ValidateRange(1, 64)]
  [int]$ImgW = 8,
  [ValidateRange(1, 8)]
  [int]$Scale = 4,
  [string]$InputRaw = "",
  [string]$InputPng = "",
  [string]$BoardRaw,
  [string]$ReferenceRaw,
  [string]$BuildDir = "board_runs\w8a12_jtag_compare",
  [string]$PreviewPng = "",
  [string]$ActualLabel = "Board W8A12"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if (-not $BoardRaw -or -not (Test-Path $BoardRaw)) {
    throw "BoardRaw not found: $BoardRaw"
  }
  if (-not $ReferenceRaw -or -not (Test-Path $ReferenceRaw)) {
    throw "ReferenceRaw not found: $ReferenceRaw"
  }
  if ($InputRaw -eq "" -and $InputPng -eq "") {
    throw "Either InputRaw or InputPng is required"
  }

  $outW = $ImgW * $Scale
  $outH = $ImgW * $Scale
  $expectedBytes = 3 * $outW * $outH
  $boardBytes = [System.IO.File]::ReadAllBytes($BoardRaw)
  $refBytes = [System.IO.File]::ReadAllBytes($ReferenceRaw)
  if ($boardBytes.Length -ne $expectedBytes) {
    throw "Board raw size mismatch: got $($boardBytes.Length), expected $expectedBytes"
  }
  if ($refBytes.Length -ne $expectedBytes) {
    throw "Reference raw size mismatch: got $($refBytes.Length), expected $expectedBytes"
  }

  $buildAbs = if ([System.IO.Path]::IsPathRooted($BuildDir)) {
    [System.IO.Path]::GetFullPath($BuildDir)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $root $BuildDir))
  }
  New-Item -ItemType Directory -Path $buildAbs -Force | Out-Null

  $tag = "x{0}_{1}x{1}" -f $Scale, $ImgW
  if ($InputRaw -eq "") {
    $InputRaw = Join-Path $buildAbs ("w8a12_input_$tag.rgb")
    python tools\convert_rgb_raw.py to-raw $InputPng $InputRaw --width $ImgW --height $ImgW
    if ($LASTEXITCODE -ne 0) {
      throw "convert_rgb_raw.py input conversion failed with exit code $LASTEXITCODE"
    }
  }

  $inputPng = Join-Path $buildAbs ("w8a12_input_$tag.png")
  $refPng = Join-Path $buildAbs ("w8a12_reference_$tag.png")
  $boardPng = Join-Path $buildAbs ("w8a12_board_$tag.png")
  if ($PreviewPng -eq "") {
    $PreviewPng = Join-Path $buildAbs ("w8a12_validation_preview_$tag.png")
  }

  python tools\convert_rgb_raw.py from-raw $InputRaw $inputPng --width $ImgW --height $ImgW
  if ($LASTEXITCODE -ne 0) {
    throw "convert_rgb_raw.py input PNG conversion failed with exit code $LASTEXITCODE"
  }
  python tools\convert_rgb_raw.py from-raw $ReferenceRaw $refPng --width $outW --height $outH
  if ($LASTEXITCODE -ne 0) {
    throw "convert_rgb_raw.py reference PNG conversion failed with exit code $LASTEXITCODE"
  }
  python tools\convert_rgb_raw.py from-raw $BoardRaw $boardPng --width $outW --height $outH
  if ($LASTEXITCODE -ne 0) {
    throw "convert_rgb_raw.py board PNG conversion failed with exit code $LASTEXITCODE"
  }

  python tools\make_sr_validation_preview.py `
    --input $InputRaw `
    --input-width $ImgW `
    --input-height $ImgW `
    --ref $refPng `
    --actual $boardPng `
    --actual-label $ActualLabel `
    --out $PreviewPng `
    --title "JTAG W8A12 SPAN x${Scale} ${ImgW}x${ImgW}"
  if ($LASTEXITCODE -ne 0) {
    throw "make_sr_validation_preview.py failed with exit code $LASTEXITCODE"
  }

  $mismatch = 0
  $maxDiff = 0
  $signedDiffSum = 0
  $sse = 0.0
  for ($i = 0; $i -lt $boardBytes.Length; $i++) {
    $signedDiff = [int]$boardBytes[$i] - [int]$refBytes[$i]
    $diff = [Math]::Abs($signedDiff)
    if ($signedDiff -ne 0) {
      $mismatch++
      if ($mismatch -le 16) {
        Write-Host ("Mismatch byte {0}: board=0x{1:X2}, ref=0x{2:X2}" -f $i, $boardBytes[$i], $refBytes[$i])
      }
    }
    if ($diff -gt $maxDiff) {
      $maxDiff = $diff
    }
    $signedDiffSum += $signedDiff
    $sse += ($signedDiff * $signedDiff)
  }
  $mse = $sse / [double]$boardBytes.Length
  $psnrDb = if ($mse -eq 0.0) { "Infinity" } else { 10.0 * [Math]::Log10((255.0 * 255.0) / $mse) }
  $mae = 0.0
  for ($i = 0; $i -lt $boardBytes.Length; $i++) {
    $mae += [Math]::Abs([int]$boardBytes[$i] - [int]$refBytes[$i])
  }
  $mae = $mae / [double]$boardBytes.Length

  $summary = [ordered]@{
    status = if ($mismatch -eq 0) { "PASS" } else { "FAIL" }
    scale = $Scale
    img_w = $ImgW
    output_w = $outW
    output_h = $outH
    input_raw = $InputRaw
    board_raw = $BoardRaw
    reference_raw = $ReferenceRaw
    input_png = $inputPng
    board_png = $boardPng
    reference_png = $refPng
    preview_png = $PreviewPng
    total_bytes = $boardBytes.Length
    mismatch_bytes = $mismatch
    max_channel_diff = $maxDiff
    mae = $mae
    mse = $mse
    psnr_db = $psnrDb
    mean_signed_diff = ($signedDiffSum / [double]$boardBytes.Length)
  }
  $summaryJson = Join-Path $buildAbs ("w8a12_compare_summary_$tag.json")
  $summaryMd = Join-Path $buildAbs ("w8a12_compare_summary_$tag.md")
  $summary | ConvertTo-Json -Depth 4 | Set-Content -Path $summaryJson -Encoding UTF8
  $lines = @(
    "# JTAG W8A12 SPAN Output Comparison",
    "",
    "Status: ``$($summary.status)``",
    "Target: X$Scale ``${ImgW}x${ImgW} -> ${outW}x${outH}``",
    "Preview: ``$PreviewPng``",
    "",
    "## Metrics",
    "",
    "- mismatch bytes: ``$mismatch / $($boardBytes.Length)``",
    "- max channel diff: ``$maxDiff``",
    "- MAE: ``$mae``",
    "- MSE: ``$mse``",
    "- PSNR(dB): ``$psnrDb``",
    "",
    "## Artifacts",
    "",
    "- input PNG: ``$inputPng``",
    "- reference PNG: ``$refPng``",
    "- board PNG: ``$boardPng``",
    "- summary JSON: ``$summaryJson``",
    ""
  )
  Set-Content -Path $summaryMd -Value $lines -Encoding UTF8

  if ($mismatch -ne 0) {
    throw "JTAG W8A12 output mismatch count: $mismatch"
  }

  Write-Host "PASS compare_jtag_w8a12_span_output_x${Scale}_${ImgW}x${ImgW}: $($boardBytes.Length) bytes match"
  Write-Host "SUMMARY=$summaryMd"
  Write-Host "PREVIEW_PNG=$PreviewPng"
}
finally {
  Pop-Location
}
