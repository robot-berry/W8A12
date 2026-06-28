param(
  [string]$Bitstream = "vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_true2x2_jtagaxi_stagehash_20260628.bit",
  [string]$PsuInitTcl = "vivado\jwtw_true2x2_jtagaxi_stagehash_20260628\jwtw.gen\sources_1\bd\jwtw\ip\jwtw_ps_0\psu_init.tcl",
  [string]$InputRaw = "runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference\input.rgb",
  [string]$ReferenceRaw = "runs\reds_span_quant_plan\endpoint_content_2x2_tile2x2_h21_ol1_tl4_sl1\reference.rgb",
  [string]$OutputDir = "board_runs\jtag_w8a12_tile_writer\true2x2_stagehash_acceptance_20260628",
  [int]$OutputWaitTries = 5000,
  [int]$PerfWaitTries = 5000,
  [int]$InputReadyTries = 1000000,
  [switch]$SkipInitialProbe,
  [switch]$ContinueOnError
)

$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

Push-Location $Repo
try {
  $args = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", "scripts\run_w8a12_stagehash_true2x2_acceptance.ps1",
    "-Bitstream", $Bitstream,
    "-PsuInitTcl", $PsuInitTcl,
    "-InputRaw", $InputRaw,
    "-ReferenceRaw", $ReferenceRaw,
    "-OutputDir", $OutputDir,
    "-OutputWaitTries", "$OutputWaitTries",
    "-PerfWaitTries", "$PerfWaitTries",
    "-InputReadyTries", "$InputReadyTries"
  )
  if ($SkipInitialProbe) { $args += "-SkipInitialProbe" }
  if ($ContinueOnError) { $args += "-ContinueOnError" }
  & powershell @args
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} finally {
  Pop-Location
}
