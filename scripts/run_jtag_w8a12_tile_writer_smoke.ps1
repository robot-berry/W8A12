param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [string]$Bitstream = "vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_20260627.bit",
  [string]$CtrlBase = "0xA0000000",
  [ValidateRange(1, 64)]
  [int]$ImgW = 2,
  [ValidateRange(1, 64)]
  [int]$ImgH = 2,
  [ValidateRange(1, 8)]
  [int]$Scale = 4,
  [string]$InputRaw = "runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb",
  [string]$ReferenceRaw = "runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb",
  [string]$OutputDir = "",
  [switch]$NoProgram,
  [switch]$PerfOnly,
  [int]$MaxOutputPixels = 0,
  [int]$InputReadyTries = 1000000,
  [int]$OutputWaitTries = 5000000,
  [int]$PerfWaitTries = 5000000,
  [switch]$SkipCompare
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-WorkspacePath {
  param([string]$PathValue)
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Resolve-ExternalExitCode {
  param([object]$LastExitCode, [bool]$Success)
  if ($null -ne $LastExitCode) { return [int]$LastExitCode }
  if ($Success) { return 0 }
  return 1
}

function Get-LastRegexGroup {
  param([string]$Text, [string]$Pattern)
  $matches = [regex]::Matches($Text, $Pattern)
  if ($matches.Count -gt 0) {
    return $matches[$matches.Count - 1].Groups[1].Value.Trim()
  }
  return ""
}

Push-Location $root
try {
  if (-not (Test-Path $VivadoBat)) {
    throw "Vivado batch executable not found: $VivadoBat"
  }

  $inputAbs = Resolve-WorkspacePath $InputRaw
  $refAbs = Resolve-WorkspacePath $ReferenceRaw
  if (-not (Test-Path $inputAbs)) { throw "Input raw not found: $inputAbs" }
  if (-not $PerfOnly -and -not $SkipCompare -and -not (Test-Path $refAbs)) {
    throw "Reference raw not found: $refAbs"
  }

  $bitAbs = ""
  if (-not $NoProgram) {
    $bitAbs = Resolve-WorkspacePath $Bitstream
    if (-not (Test-Path $bitAbs)) { throw "Bitstream not found: $bitAbs" }
  }

  if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = "board_runs\jtag_w8a12_tile_writer\true${ImgW}x${ImgH}_x${Scale}_$stamp"
  }
  $outDirAbs = Resolve-WorkspacePath $OutputDir
  New-Item -ItemType Directory -Path $outDirAbs -Force | Out-Null

  $boardRaw = Join-Path $outDirAbs "board_output.rgb"
  $vivadoLog = Join-Path $outDirAbs "jtag_w8a12_tile_writer_smoke.log"
  $vivadoJournal = Join-Path $outDirAbs "jtag_w8a12_tile_writer_smoke.jou"
  $stdoutLog = Join-Path $outDirAbs "jtag_w8a12_tile_writer_smoke.stdout.log"
  $stderrLog = Join-Path $outDirAbs "jtag_w8a12_tile_writer_smoke.stderr.log"
  $summaryJson = Join-Path $outDirAbs "jtag_w8a12_tile_writer_smoke_summary.json"
  $summaryMd = Join-Path $outDirAbs "jtag_w8a12_tile_writer_smoke_summary.md"

  $tcl = Join-Path $root "scripts\jtag_rgb_transfer.tcl"
  $args = @(
    "-mode", "batch",
    "-log", $vivadoLog,
    "-journal", $vivadoJournal,
    "-source", $tcl,
    "-tclargs",
    "--input", $inputAbs,
    "--output", $boardRaw,
    "--base", $CtrlBase,
    "--width", $ImgW,
    "--height", $ImgH,
    "--scale", $Scale
  )
  if (-not $NoProgram) {
    $args += @("--bitstream", $bitAbs)
  }
  if ($PerfOnly) {
    $args += @("--perf-only")
  }
  if ($MaxOutputPixels -gt 0) {
    $args += @("--max-output-pixels", $MaxOutputPixels)
  }
  $args += @(
    "--input-ready-tries", $InputReadyTries,
    "--output-wait-tries", $OutputWaitTries,
    "--perf-wait-tries", $PerfWaitTries
  )

  Write-Host "JTAG_W8A12_SMOKE_OUTPUT_DIR=$outDirAbs"
  Write-Host "JTAG_W8A12_SMOKE_BITSTREAM=$bitAbs"
  Write-Host "JTAG_W8A12_SMOKE_INPUT_RAW=$inputAbs"
  Write-Host "JTAG_W8A12_SMOKE_BOARD_RAW=$boardRaw"
  Write-Host "JTAG_W8A12_SMOKE_STDOUT_LOG=$stdoutLog"
  Write-Host "JTAG_W8A12_SMOKE_STDERR_LOG=$stderrLog"

  $nativeErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $VivadoBat @args 1> $stdoutLog 2> $stderrLog
    $exitCode = Resolve-ExternalExitCode $LASTEXITCODE $?
  } finally {
    $ErrorActionPreference = $nativeErrorActionPreference
  }

  $stdoutText = if (Test-Path $stdoutLog) { Get-Content -Path $stdoutLog -Raw } else { "" }
  $stderrText = if (Test-Path $stderrLog) { Get-Content -Path $stderrLog -Raw } else { "" }
  $frameCycles = Get-LastRegexGroup $stdoutText "JTAG_FRAME_CYCLES=([^`r`n]+)"
  $frameDone = Get-LastRegexGroup $stdoutText "JTAG_FRAME_DONE=([^`r`n]+)"
  $e2eCycles = Get-LastRegexGroup $stdoutText "JTAG_E2E_CYCLES=([^`r`n]+)"
  $errorFlags = Get-LastRegexGroup $stdoutText "Error flags\s*:\s*(0x[0-9A-Fa-f]+)"
  $inputCounter = Get-LastRegexGroup $stdoutText "Input counter\s*:\s*([0-9]+)"
  $outputCounter = Get-LastRegexGroup $stdoutText "Output counter\s*:\s*([0-9]+)"

  $expectedBytes = 3 * $ImgW * $ImgH * $Scale * $Scale
  if ($MaxOutputPixels -gt 0 -and $MaxOutputPixels -lt ($ImgW * $ImgH * $Scale * $Scale)) {
    $expectedBytes = 3 * $MaxOutputPixels
  }
  $boardBytes = if (Test-Path $boardRaw) { (Get-Item $boardRaw).Length } else { 0 }

  $compareStatus = "SKIPPED"
  $compareSummary = ""
  $previewPng = ""
  if (-not $PerfOnly -and -not $SkipCompare -and $exitCode -eq 0 -and $boardBytes -eq $expectedBytes) {
    $compareDir = Join-Path $outDirAbs "compare"
    $comparePreview = Join-Path $compareDir "jtag_w8a12_validation_preview.png"
    $nativeErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      & powershell -NoProfile -ExecutionPolicy Bypass -File scripts\compare_jtag_w8a12_span_output.ps1 `
        -ImgW $ImgW `
        -Scale $Scale `
        -InputRaw $inputAbs `
        -BoardRaw $boardRaw `
        -ReferenceRaw $refAbs `
        -BuildDir $compareDir `
        -PreviewPng $comparePreview `
        -ActualLabel "Board JTAG W8A12"
      $compareExit = Resolve-ExternalExitCode $LASTEXITCODE $?
    } finally {
      $ErrorActionPreference = $nativeErrorActionPreference
    }
    $compareStatus = if ($compareExit -eq 0) { "PASS" } else { "FAIL" }
    $compareSummary = Join-Path $compareDir ("w8a12_compare_summary_x{0}_{1}x{1}.md" -f $Scale, $ImgW)
    $previewPng = $comparePreview
  } elseif ($PerfOnly) {
    $compareStatus = "PERF_ONLY"
  }

  $status = "FAIL"
  if ($PerfOnly) {
    if ($exitCode -eq 0 -and $frameDone -eq "1" -and ($errorFlags -eq "" -or $errorFlags -eq "0x00000000")) {
      $status = "PASS"
    }
  } elseif ($exitCode -eq 0 -and $boardBytes -eq $expectedBytes -and ($compareStatus -eq "PASS" -or $SkipCompare)) {
    $status = "PASS"
  }

  $summary = [ordered]@{
    status = $status
    vivado_exit_code = $exitCode
    compare_status = $compareStatus
    img_w = $ImgW
    img_h = $ImgH
    scale = $Scale
    ctrl_base = $CtrlBase
    no_program = [bool]$NoProgram
    perf_only = [bool]$PerfOnly
    max_output_pixels = $MaxOutputPixels
    input_ready_tries = $InputReadyTries
    output_wait_tries = $OutputWaitTries
    perf_wait_tries = $PerfWaitTries
    expected_output_bytes = $expectedBytes
    board_output_bytes = $boardBytes
    bitstream = $bitAbs
    input_raw = $inputAbs
    reference_raw = $refAbs
    board_raw = $boardRaw
    compare_summary = $compareSummary
    preview_png = $previewPng
    frame_cycles = $frameCycles
    frame_done = $frameDone
    e2e_cycles = $e2eCycles
    error_flags = $errorFlags
    input_counter = $inputCounter
    output_counter = $outputCounter
    stdout_log = $stdoutLog
    stderr_log = $stderrLog
    vivado_log = $vivadoLog
  }
  $summary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryJson -Encoding UTF8

  $lines = @(
    "# JTAG W8A12 Tile Writer Smoke Summary",
    "",
    "Status: $($summary.status)",
    "",
    "| Item | Value |",
    "| --- | --- |",
    "| Vivado exit | $($summary.vivado_exit_code) |",
    "| compare | $($summary.compare_status) |",
    "| image | ${ImgW}x${ImgH} -> $($ImgW * $Scale)x$($ImgH * $Scale) |",
    "| ctrl base | ``$CtrlBase`` |",
    "| bitstream | ``$bitAbs`` |",
    "| input raw | ``$inputAbs`` |",
    "| reference raw | ``$refAbs`` |",
    "| board raw | ``$boardRaw`` |",
    "| output bytes | $boardBytes / $expectedBytes |",
    "| frame done | ``$frameDone`` |",
    "| frame cycles | ``$frameCycles`` |",
    "| e2e cycles | ``$e2eCycles`` |",
    "| error flags | ``$errorFlags`` |",
    "| input counter | ``$inputCounter`` |",
    "| output counter | ``$outputCounter`` |",
    "| compare summary | ``$compareSummary`` |",
    "| preview | ``$previewPng`` |",
    "| stdout log | ``$stdoutLog`` |",
    "| stderr log | ``$stderrLog`` |",
    "| vivado log | ``$vivadoLog`` |",
    "| summary JSON | ``$summaryJson`` |"
  )
  Set-Content -Path $summaryMd -Value $lines -Encoding UTF8

  Write-Host "JTAG_W8A12_SMOKE_SUMMARY_JSON=$summaryJson"
  Write-Host "JTAG_W8A12_SMOKE_SUMMARY_MD=$summaryMd"
  Write-Host "JTAG_W8A12_SMOKE_STATUS=$($summary.status)"

  if ($summary.status -ne "PASS") {
    if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
      Write-Host "JTAG_W8A12_SMOKE_STDERR_TAIL_BEGIN"
      Get-Content -Path $stderrLog -Tail 40 | ForEach-Object { Write-Host $_ }
      Write-Host "JTAG_W8A12_SMOKE_STDERR_TAIL_END"
    }
    throw "JTAG W8A12 tile writer smoke failed"
  }
} finally {
  Pop-Location
}
