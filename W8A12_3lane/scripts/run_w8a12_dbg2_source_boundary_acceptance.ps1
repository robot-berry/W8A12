param(
  [string]$Bitstream = "vivado\bitstreams\jtag_w8a12_tile_writer_x4_imgw2_tile2x2_h21_f25m_ol1_tl4_sl1_dbg2_true2x2_jtagaxi_dbg2_src_boundary_20260629.bit",
  [string]$PsuInitTcl = "vivado\jwtw_true2x2_jtagaxi_dbg2_src_boundary_20260629\jwtw.gen\sources_1\bd\jwtw\ip\jwtw_ps_0\psu_init.tcl",
  [string]$OutputDir = "board_runs\jtag_w8a12_tile_writer\true2x2_dbg2_src_boundary_acceptance_current",
  [string]$PreflightDir = "board_runs\w8a12_board_recovery_preflight\dbg2_src_boundary_current",
  [string]$PreconditionOutDir = "W8A12_3lane\evidence\board_probe\jtag_precondition_current",
  [string]$EvidenceDir = "W8A12_3lane\evidence\board_reports\jtag_true2x2_dbg2_src_boundary_current",
  [switch]$ForceVivadoProbe,
  [switch]$SkipPreflight,
  [switch]$ContinueOnError,
  [switch]$FailOnBlocked
)

$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
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
  return [System.IO.Path]::GetFullPath((Join-Path $Repo $PathValue))
}

function Read-JsonFile {
  param([string]$PathValue)
  $text = [System.IO.File]::ReadAllText($PathValue, [System.Text.Encoding]::UTF8)
  if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) {
    $text = $text.Substring(1)
  }
  return $text | ConvertFrom-Json
}

function Invoke-LoggedStep {
  param(
    [string]$Name,
    [string[]]$Arguments,
    [string]$LogPath
  )
  Write-Host "W8A12_DBG2_STEP_BEGIN=$Name"
  Write-Host "W8A12_DBG2_STEP_LOG=$LogPath"
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
  Write-Host "W8A12_DBG2_STEP_EXIT_$Name=$exitCode"
  return $exitCode
}

Push-Location $Repo
try {
  $bitAbs = Resolve-WorkspacePath $Bitstream
  $psuAbs = Resolve-WorkspacePath $PsuInitTcl
  $outAbs = Resolve-WorkspacePath $OutputDir
  $preflightAbs = Resolve-WorkspacePath $PreflightDir
  $preconditionAbs = Resolve-WorkspacePath $PreconditionOutDir
  $evidenceAbs = Resolve-WorkspacePath $EvidenceDir
  New-Item -ItemType Directory -Path $outAbs -Force | Out-Null
  New-Item -ItemType Directory -Path $preflightAbs -Force | Out-Null
  New-Item -ItemType Directory -Path $preconditionAbs -Force | Out-Null
  New-Item -ItemType Directory -Path $evidenceAbs -Force | Out-Null

  if (-not (Test-Path $bitAbs)) { throw "Bitstream not found: $bitAbs" }
  if (-not (Test-Path $psuAbs)) { throw "psu_init.tcl not found: $psuAbs" }

  $summaryJson = Join-Path $evidenceAbs "summary.json"
  $summaryMd = Join-Path $evidenceAbs "summary.md"
  $steps = [ordered]@{}
  $status = "UNKNOWN"
  $preStatus = "SKIPPED"
  $usbKnown = ""
  $vivadoTargets = ""

  if (-not $SkipPreflight) {
    $preflightLog = Join-Path $evidenceAbs "preflight_step.log"
    $preArgs = @(
      "-NoProfile", "-ExecutionPolicy", "Bypass",
      "-File", "W8A12_3lane\scripts\run_w8a12_board_recovery_preflight.ps1",
      "-OutputDir", $preflightAbs,
      "-PreconditionOutDir", $preconditionAbs
    )
    if ($ForceVivadoProbe) { $preArgs += "-ForceVivadoProbe" }
    $preExit = Invoke-LoggedStep -Name "preflight" -LogPath $preflightLog -Arguments $preArgs
    $steps.preflight = [ordered]@{
      exit = $preExit
      log = $preflightLog
      output_dir = $preflightAbs
      precondition_dir = $preconditionAbs
    }

    $preJson = Join-Path $preconditionAbs "summary.json"
    if (Test-Path $preJson) {
      $preData = Read-JsonFile $preJson
      $preStatus = [string]$preData.status
      $usbKnown = [string]$preData.usb_known_jtag_candidate_count
      $vivadoTargets = [string]$preData.vivado_target_count
    } else {
      $preStatus = "MISSING"
    }
  } else {
    $steps.preflight = [ordered]@{ exit = "skipped"; reason = "SkipPreflight was set" }
    $preStatus = "READY"
  }

  if ($preStatus -eq "READY") {
    $acceptLog = Join-Path $evidenceAbs "acceptance_step.log"
    $acceptArgs = @(
      "-NoProfile", "-ExecutionPolicy", "Bypass",
      "-File", "W8A12_3lane\scripts\run_w8a12_stagehash_true2x2_acceptance.ps1",
      "-Bitstream", $bitAbs,
      "-PsuInitTcl", $psuAbs,
      "-OutputDir", $outAbs,
      "-OutputWaitTries", "5000",
      "-PerfWaitTries", "5000",
      "-InputReadyTries", "1000000"
    )
    if ($ContinueOnError) { $acceptArgs += "-ContinueOnError" }
    $acceptExit = Invoke-LoggedStep -Name "dbg2_acceptance" -LogPath $acceptLog -Arguments $acceptArgs
    $steps.dbg2_acceptance = [ordered]@{ exit = $acceptExit; log = $acceptLog; output_dir = $outAbs }
    $status = if ($acceptExit -eq 0) { "PASS" } else { "FAIL" }
  } else {
    $steps.dbg2_acceptance = [ordered]@{
      exit = "skipped"
      reason = "JTAG precondition is not READY"
      output_dir = $outAbs
    }
    $status = "BLOCKED"
  }

  $summary = [ordered]@{
    status = $status
    bitstream = $bitAbs
    psu_init_tcl = $psuAbs
    output_dir = $outAbs
    preflight_dir = $preflightAbs
    precondition_dir = $preconditionAbs
    precondition_status = $preStatus
    usb_known_jtag_candidate_count = $usbKnown
    vivado_target_count = $vivadoTargets
    expected_rtl_hashes = [ordered]@{
      tail_b1_hash = "0x16ede1c2"
      tail_b6_act1_hash = "0xc7a092b8"
      tail_rgb_q_hash = "0xb712a61b"
      writeback_hash = "0x61d3ea1d"
      bank1_tail_feat0_hash = "0x000004bf"
      bank1_src_feat0_hash = "0x00000004"
      bank1_src_b1_hash = "0x00070004"
    }
    steps = $steps
  }
  $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryJson -Encoding UTF8

  $lines = @(
    "# W8A12 dbg2 source-boundary acceptance",
    "",
    "Status: $status",
    "",
    "| Field | Value |",
    "| --- | --- |",
    "| bitstream | ``$bitAbs`` |",
    "| psu_init.tcl | ``$psuAbs`` |",
    "| precondition | ``$preStatus`` |",
    "| USB known JTAG candidate count | ``$usbKnown`` |",
    "| Vivado target count | ``$vivadoTargets`` |",
    "| output dir | ``$outAbs`` |",
    "| preflight dir | ``$preflightAbs`` |",
    "| summary JSON | ``$summaryJson`` |",
    "",
    "## Expected RTL hashes",
    "",
    "| Signal | Value |",
    "| --- | --- |",
    "| tail_b1_hash | ``0x16ede1c2`` |",
    "| tail_b6_act1_hash | ``0xc7a092b8`` |",
    "| tail_rgb_q_hash | ``0xb712a61b`` |",
    "| writeback_hash | ``0x61d3ea1d`` |",
    "| bank1_tail_feat0_hash | ``0x000004bf`` |",
    "| bank1_src_feat0_hash | ``0x00000004`` |",
    "| bank1_src_b1_hash | ``0x00070004`` |",
    "",
    "## Next Step",
    ""
  )
  if ($status -eq "BLOCKED") {
    $lines += "Restore board USB/JTAG visibility, then rerun this script. It will automatically enter dbg2 acceptance when the precondition becomes READY."
  } elseif ($status -eq "PASS") {
    $lines += "Compare board bank1 hashes against the expected RTL hashes and decide whether to keep probing source/tap or move to replay/tail."
  } else {
    $lines += "Inspect the acceptance output directory and register-read summary to classify mismatch/stall/error."
  }
  Set-Content -Path $summaryMd -Value $lines -Encoding UTF8

  Write-Host "W8A12_DBG2_ACCEPTANCE_SUMMARY_JSON=$summaryJson"
  Write-Host "W8A12_DBG2_ACCEPTANCE_SUMMARY_MD=$summaryMd"
  Write-Host "W8A12_DBG2_ACCEPTANCE_STATUS=$status"

  if ($status -eq "BLOCKED" -and $FailOnBlocked) { exit 1 }
  if ($status -eq "FAIL" -and -not $ContinueOnError) { exit 1 }
} finally {
  Pop-Location
}
