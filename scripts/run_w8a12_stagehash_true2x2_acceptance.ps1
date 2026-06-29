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
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$PowerShellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $PowerShellExe)) {
  throw "PowerShell executable not found: $PowerShellExe"
}

function Resolve-WorkspacePath {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return "" }
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Invoke-Step {
  param(
    [string]$Name,
    [string[]]$Arguments,
    [string]$LogPath
  )
  Write-Host "W8A12_STAGEHASH_STEP_BEGIN=$Name"
  Write-Host "W8A12_STAGEHASH_STEP_LOG=$LogPath"
  $oldPreference = $ErrorActionPreference
  $exitCode = 1
  try {
    $ErrorActionPreference = "Continue"
    & $PowerShellExe @Arguments *>&1 | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
    if ($null -ne $LASTEXITCODE) {
      $exitCode = [int]$LASTEXITCODE
    } elseif ($?) {
      $exitCode = 0
    } else {
      $exitCode = 1
    }
  } finally {
    $ErrorActionPreference = $oldPreference
  }
  Write-Host "W8A12_STAGEHASH_STEP_EXIT_$Name=$exitCode"
  return $exitCode
}

Push-Location $root
try {
  $bitAbs = Resolve-WorkspacePath $Bitstream
  $psuInitAbs = Resolve-WorkspacePath $PsuInitTcl
  $inputAbs = Resolve-WorkspacePath $InputRaw
  $refAbs = Resolve-WorkspacePath $ReferenceRaw
  $outDirAbs = Resolve-WorkspacePath $OutputDir
  New-Item -ItemType Directory -Path $outDirAbs -Force | Out-Null

  if (-not (Test-Path $bitAbs)) { throw "Bitstream not found: $bitAbs" }
  if (-not (Test-Path $psuInitAbs)) { throw "psu_init.tcl not found: $psuInitAbs" }
  if (-not (Test-Path $inputAbs)) { throw "Input raw not found: $inputAbs" }
  if (-not (Test-Path $refAbs)) { throw "Reference raw not found: $refAbs" }

  $summaryJson = Join-Path $outDirAbs "stagehash_true2x2_acceptance_summary.json"
  $summaryMd = Join-Path $outDirAbs "stagehash_true2x2_acceptance_summary.md"
  $steps = [ordered]@{}
  $status = "PASS"

  if (-not $SkipInitialProbe) {
    $probeDir = Join-Path $outDirAbs "probe"
    $probeLog = Join-Path $outDirAbs "probe_step.log"
    $probeExit = Invoke-Step -Name "probe" -LogPath $probeLog -Arguments @(
      "-NoProfile", "-ExecutionPolicy", "Bypass",
      "-File", "scripts\probe_vivado_hw_targets.ps1",
      "-OutputDir", $probeDir
    )
    $steps.probe = [ordered]@{ exit = $probeExit; log = $probeLog; output_dir = $probeDir }
    if ($probeExit -ne 0) {
      $status = "FAIL"
      if (-not $ContinueOnError) {
        throw "Initial Vivado target probe failed"
      }
    }
  }

  $psuDir = Join-Path $outDirAbs "psu_init"
  $psuLog = Join-Path $outDirAbs "psu_init_step.log"
  $psuExit = Invoke-Step -Name "psu_init" -LogPath $psuLog -Arguments @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", "scripts\run_xsct_psu_init_only.ps1",
    "-PsuInitTcl", $psuInitAbs,
    "-OutputDir", $psuDir
  )
  $steps.psu_init = [ordered]@{ exit = $psuExit; log = $psuLog; output_dir = $psuDir }
  if ($psuExit -ne 0) {
    $status = "FAIL"
    if (-not $ContinueOnError) {
      throw "PSU init failed"
    }
  }

  $smokeDir = Join-Path $outDirAbs "smoke"
  $smokeLog = Join-Path $outDirAbs "smoke_step.log"
  $smokeExit = Invoke-Step -Name "smoke" -LogPath $smokeLog -Arguments @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", "scripts\run_jtag_w8a12_tile_writer_smoke.ps1",
    "-Bitstream", $bitAbs,
    "-ImgW", "2",
    "-ImgH", "2",
    "-Scale", "4",
    "-InputRaw", $inputAbs,
    "-ReferenceRaw", $refAbs,
    "-OutputDir", $smokeDir,
    "-OutputWaitTries", "$OutputWaitTries",
    "-PerfWaitTries", "$PerfWaitTries",
    "-InputReadyTries", "$InputReadyTries"
  )
  $steps.smoke = [ordered]@{ exit = $smokeExit; log = $smokeLog; output_dir = $smokeDir }
  if ($smokeExit -ne 0) {
    $status = "FAIL"
    if (-not $ContinueOnError) {
      throw "Stage-hash smoke failed"
    }
  }

  $regDir = Join-Path $outDirAbs "reg_read_after_smoke"
  $regLog = Join-Path $outDirAbs "reg_read_step.log"
  $regExit = Invoke-Step -Name "reg_read" -LogPath $regLog -Arguments @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", "scripts\run_read_jtag_w8a12_tile_writer_regs.ps1",
    "-PollCount", "3",
    "-PollDelayMs", "200",
    "-OutputDir", $regDir
  )
  $steps.reg_read = [ordered]@{ exit = $regExit; log = $regLog; output_dir = $regDir }
  if ($regExit -ne 0) {
    $status = "FAIL"
    if (-not $ContinueOnError) {
      throw "Stage-hash register read failed"
    }
  }

  $summary = [ordered]@{
    status = $status
    bitstream = $bitAbs
    psu_init_tcl = $psuInitAbs
    input_raw = $inputAbs
    reference_raw = $refAbs
    output_dir = $outDirAbs
    expected_hashes = [ordered]@{
      tail_b1_hash = "0x16ede1c2"
      tail_b6_act1_hash = "0xc7a092b8"
      tail_rgb_q_hash = "0xb712a61b"
      writeback_hash = "0x61d3ea1d"
      writeback_range = "0x4e9f0040"
      writeback_first = "0x0061605d"
      writeback_last = "0x007a6366"
    }
    steps = $steps
  }
  $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryJson -Encoding UTF8

  $lines = @(
    "# W8A12 Stage-Hash True2x2 Acceptance Summary",
    "",
    "Status: $status",
    "",
    "| Item | Value |",
    "| --- | --- |",
    "| bitstream | ``$bitAbs`` |",
    "| psu_init.tcl | ``$psuInitAbs`` |",
    "| input raw | ``$inputAbs`` |",
    "| reference raw | ``$refAbs`` |",
    "| expected tail_b1_hash | ``0x16ede1c2`` |",
    "| expected tail_b6_act1_hash | ``0xc7a092b8`` |",
    "| expected tail_rgb_q_hash | ``0xb712a61b`` |",
    "| expected writeback_hash | ``0x61d3ea1d`` |",
    "| probe dir | ``$($steps.probe.output_dir)`` |",
    "| psu init dir | ``$($steps.psu_init.output_dir)`` |",
    "| smoke dir | ``$($steps.smoke.output_dir)`` |",
    "| reg read dir | ``$($steps.reg_read.output_dir)`` |",
    "| summary JSON | ``$summaryJson`` |"
  )
  Set-Content -Path $summaryMd -Value $lines -Encoding UTF8

  Write-Host "W8A12_STAGEHASH_ACCEPTANCE_SUMMARY_JSON=$summaryJson"
  Write-Host "W8A12_STAGEHASH_ACCEPTANCE_SUMMARY_MD=$summaryMd"
  Write-Host "W8A12_STAGEHASH_ACCEPTANCE_STATUS=$status"
  if ($status -ne "PASS") {
    throw "W8A12 stage-hash true2x2 acceptance failed"
  }
} catch {
  if ($null -ne $summaryJson) {
    $summary = [ordered]@{
      status = "FAIL"
      error = $_.Exception.Message
      bitstream = $bitAbs
      psu_init_tcl = $psuInitAbs
      input_raw = $inputAbs
      reference_raw = $refAbs
      output_dir = $outDirAbs
      steps = $steps
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryJson -Encoding UTF8
    $lines = @(
      "# W8A12 Stage-Hash True2x2 Acceptance Summary",
      "",
      "Status: FAIL",
      "",
      "Error: ``$($_.Exception.Message)``",
      "",
      "| Item | Value |",
      "| --- | --- |",
      "| bitstream | ``$bitAbs`` |",
      "| psu_init.tcl | ``$psuInitAbs`` |",
      "| output dir | ``$outDirAbs`` |",
      "| summary JSON | ``$summaryJson`` |"
    )
    Set-Content -Path $summaryMd -Value $lines -Encoding UTF8
    Write-Host "W8A12_STAGEHASH_ACCEPTANCE_SUMMARY_JSON=$summaryJson"
    Write-Host "W8A12_STAGEHASH_ACCEPTANCE_SUMMARY_MD=$summaryMd"
    Write-Host "W8A12_STAGEHASH_ACCEPTANCE_STATUS=FAIL"
  }
  throw
} finally {
  Pop-Location
}
