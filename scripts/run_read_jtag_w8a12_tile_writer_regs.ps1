param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [string]$Bitstream = "",
  [string]$CtrlBase = "0xA0000000",
  [ValidateRange(1, 100)]
  [int]$PollCount = 3,
  [ValidateRange(0, 10000)]
  [int]$PollDelayMs = 200,
  [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Resolve-WorkspacePath {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return "" }
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
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

  $bitAbs = Resolve-WorkspacePath $Bitstream
  if ($bitAbs -ne "" -and -not (Test-Path $bitAbs)) {
    throw "Bitstream not found: $bitAbs"
  }

  if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = "board_runs\jtag_w8a12_tile_writer\reg_read_$stamp"
  }
  $outDirAbs = Resolve-WorkspacePath $OutputDir
  New-Item -ItemType Directory -Path $outDirAbs -Force | Out-Null

  $vivadoLog = Join-Path $outDirAbs "read_jtag_w8a12_tile_writer_regs.log"
  $vivadoJournal = Join-Path $outDirAbs "read_jtag_w8a12_tile_writer_regs.jou"
  $stdoutLog = Join-Path $outDirAbs "read_jtag_w8a12_tile_writer_regs.stdout.log"
  $stderrLog = Join-Path $outDirAbs "read_jtag_w8a12_tile_writer_regs.stderr.log"
  $summaryJson = Join-Path $outDirAbs "read_jtag_w8a12_tile_writer_regs_summary.json"
  $summaryMd = Join-Path $outDirAbs "read_jtag_w8a12_tile_writer_regs_summary.md"
  $tclScript = Join-Path $root "scripts\read_jtag_w8a12_tile_writer_regs.tcl"

  $args = @(
    "-mode", "batch",
    "-log", $vivadoLog,
    "-journal", $vivadoJournal,
    "-source", $tclScript,
    "-tclargs",
    "--base", $CtrlBase,
    "--poll-count", $PollCount,
    "--poll-delay-ms", $PollDelayMs
  )
  if ($bitAbs -ne "") {
    $args += @("--bitstream", $bitAbs)
  }

  Write-Host "JTAG_W8A12_REG_READ_OUTPUT_DIR=$outDirAbs"
  Write-Host "JTAG_W8A12_REG_READ_BITSTREAM=$bitAbs"
  Write-Host "JTAG_W8A12_REG_READ_STDOUT_LOG=$stdoutLog"
  Write-Host "JTAG_W8A12_REG_READ_STDERR_LOG=$stderrLog"

  $nativeErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & cmd.exe /d /s /c "call `"$VivadoBat`" $($args -join ' ')" 1> $stdoutLog 2> $stderrLog
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } elseif ($?) { 0 } else { 1 }
  } finally {
    $ErrorActionPreference = $nativeErrorActionPreference
  }

  $stdoutText = if (Test-Path $stdoutLog) { Get-Content -Path $stdoutLog -Raw } else { "" }
  $stderrText = if (Test-Path $stderrLog) { Get-Content -Path $stderrLog -Raw } else { "" }

  $summary = [ordered]@{
    status = if ($exitCode -eq 0 -and $stdoutText -match "Using hw_axi") { "PASS" } else { "FAIL" }
    vivado_exit_code = $exitCode
    ctrl_base = $CtrlBase
    bitstream = $bitAbs
    poll_count = $PollCount
    poll_delay_ms = $PollDelayMs
    status_reg = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_STATUS=(0x[0-9A-Fa-f]+)"
    input_flags = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_INPUT_FLAGS=(0x[0-9A-Fa-f]+)"
    input_pixel = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_INPUT_PIXEL=(0x[0-9A-Fa-f]+)"
    output_flags = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_OUTPUT_FLAGS=(0x[0-9A-Fa-f]+)"
    counter_in = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_COUNTER_IN=([0-9]+)"
    counter_out = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_COUNTER_OUT=([0-9]+)"
    error = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_ERROR=(0x[0-9A-Fa-f]+)"
    frame_cycles = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_FRAME_CYCLES=([0-9]+)"
    frame_done = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_FRAME_DONE=(0x[0-9A-Fa-f]+)"
    e2e_cycles = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_E2E_CYCLES=([0-9]+)"
    writeback_hash = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_DEBUG_WRITEBACK_HASH=(0x[0-9A-Fa-f]+)"
    writeback_range = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_DEBUG_WRITEBACK_RANGE=(0x[0-9A-Fa-f]+)"
    writeback_range_decode = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_DEBUG_WRITEBACK_RANGE_DECODE=([^\r\n]+)"
    writeback_first = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_DEBUG_WRITEBACK_FIRST=(0x[0-9A-Fa-f]+)"
    writeback_last = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_DEBUG_WRITEBACK_LAST=(0x[0-9A-Fa-f]+)"
    tail_b1_hash = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_DEBUG_TAIL_B1_HASH=(0x[0-9A-Fa-f]+)"
    tail_b6_act1_hash = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_DEBUG_TAIL_B6_ACT1_HASH=(0x[0-9A-Fa-f]+)"
    tail_rgb_q_hash = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_DEBUG_TAIL_RGB_Q_HASH=(0x[0-9A-Fa-f]+)"
    writer_live = Get-LastRegexGroup $stdoutText "JTAG_W8A12_REG_DEBUG_WRITER_LIVE=([^\r\n]+)"
    stdout_log = $stdoutLog
    stderr_log = $stderrLog
    vivado_log = $vivadoLog
    vivado_journal = $vivadoJournal
  }
  $summary | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryJson -Encoding UTF8

  $lines = @(
    "# JTAG W8A12 Register Read Summary",
    "",
    "Status: $($summary.status)",
    "",
    "| Item | Value |",
    "| --- | --- |",
    "| Vivado exit | $($summary.vivado_exit_code) |",
    "| ctrl base | ``$CtrlBase`` |",
    "| bitstream | ``$bitAbs`` |",
    "| poll count | $PollCount |",
    "| status | ``$($summary.status_reg)`` |",
    "| input flags / tail b1 hash | ``$($summary.input_flags)`` |",
    "| input pixel / tail b6 act1 hash | ``$($summary.input_pixel)`` |",
    "| output flags / tail rgb q hash | ``$($summary.output_flags)`` |",
    "| counter in | ``$($summary.counter_in)`` |",
    "| counter out | ``$($summary.counter_out)`` |",
    "| error | ``$($summary.error)`` |",
    "| frame cycles | ``$($summary.frame_cycles)`` |",
    "| frame done | ``$($summary.frame_done)`` |",
    "| e2e cycles | ``$($summary.e2e_cycles)`` |",
    "| writeback hash | ``$($summary.writeback_hash)`` |",
    "| writeback range | ``$($summary.writeback_range)`` |",
    "| writeback range decode | ``$($summary.writeback_range_decode)`` |",
    "| writeback first | ``$($summary.writeback_first)`` |",
    "| writeback last | ``$($summary.writeback_last)`` |",
    "| tail b1 hash | ``$($summary.tail_b1_hash)`` |",
    "| tail b6 act1 hash | ``$($summary.tail_b6_act1_hash)`` |",
    "| tail rgb q hash | ``$($summary.tail_rgb_q_hash)`` |",
    "| writer live | ``$($summary.writer_live)`` |",
    "| stdout log | ``$stdoutLog`` |",
    "| stderr log | ``$stderrLog`` |",
    "| vivado log | ``$vivadoLog`` |",
    "| summary JSON | ``$summaryJson`` |"
  )
  Set-Content -Path $summaryMd -Value $lines -Encoding UTF8

  Write-Host "JTAG_W8A12_REG_READ_SUMMARY_JSON=$summaryJson"
  Write-Host "JTAG_W8A12_REG_READ_SUMMARY_MD=$summaryMd"
  Write-Host "JTAG_W8A12_REG_READ_STATUS=$($summary.status)"

  if ($summary.status -ne "PASS") {
    if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
      Write-Host "JTAG_W8A12_REG_READ_STDERR_TAIL_BEGIN"
      Get-Content -Path $stderrLog -Tail 40 | ForEach-Object { Write-Host $_ }
      Write-Host "JTAG_W8A12_REG_READ_STDERR_TAIL_END"
    }
    throw "JTAG W8A12 register read failed"
  }
} finally {
  Pop-Location
}
