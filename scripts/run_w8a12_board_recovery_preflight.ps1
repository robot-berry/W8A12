param(
  [string]$OutputDir = "board_runs\w8a12_board_recovery_preflight",
  [string]$PreconditionOutDir = "W8A12_3lane\evidence\board_probe\jtag_precondition_current",
  [switch]$ForceVivadoProbe,
  [switch]$SkipVivadoProbe,
  [switch]$RunStageHashAcceptance,
  [switch]$FailOnBlocked
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$PowerShellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $PowerShellExe)) {
  throw "PowerShell executable not found: $PowerShellExe"
}

function Resolve-WorkspacePath {
  param([string]$PathValue)
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Invoke-LoggedStep {
  param(
    [string]$Name,
    [string[]]$Arguments,
    [string]$LogPath
  )
  Write-Host "W8A12_RECOVERY_STEP_BEGIN=$Name"
  Write-Host "W8A12_RECOVERY_STEP_LOG=$LogPath"
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
  Write-Host "W8A12_RECOVERY_STEP_EXIT_$Name=$exitCode"
  return $exitCode
}

function Read-JsonFile {
  param([string]$PathValue)
  $text = [System.IO.File]::ReadAllText($PathValue, [System.Text.Encoding]::UTF8)
  if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) {
    $text = $text.Substring(1)
  }
  return $text | ConvertFrom-Json
}

Push-Location $root
try {
  $outDirAbs = Resolve-WorkspacePath $OutputDir
  $preconditionOutAbs = Resolve-WorkspacePath $PreconditionOutDir
  New-Item -ItemType Directory -Path $outDirAbs -Force | Out-Null
  New-Item -ItemType Directory -Path $preconditionOutAbs -Force | Out-Null

  $summaryJson = Join-Path $outDirAbs "board_recovery_preflight_summary.json"
  $summaryMd = Join-Path $outDirAbs "board_recovery_preflight_summary.md"
  $steps = [ordered]@{}

  $usbDir = Join-Path $outDirAbs "usb"
  $usbLog = Join-Path $outDirAbs "usb_step.log"
  $usbExit = Invoke-LoggedStep -Name "usb" -LogPath $usbLog -Arguments @(
    "-NoProfile", "-ExecutionPolicy", "Bypass",
    "-File", "scripts\check_usb_jtag_devices.ps1",
    "-OutputDir", $usbDir
  )
  $usbJson = Join-Path $usbDir "usb_jtag_devices.json"
  $knownCount = 0
  if (Test-Path $usbJson) {
    $usbData = Read-JsonFile $usbJson
    $knownCount = [int]$usbData.KnownJtagCandidateCount
  }
  $steps.usb = [ordered]@{ exit = $usbExit; log = $usbLog; output_dir = $usbDir; known_jtag_candidate_count = $knownCount }

  $probeDir = ""
  $probeExit = $null
  if ($SkipVivadoProbe) {
    $steps.vivado_probe = [ordered]@{
      exit = "skipped"
      reason = "SkipVivadoProbe was requested; USB-only precondition evidence was generated without starting Vivado"
      output_dir = ""
    }
  } elseif ($ForceVivadoProbe -or $knownCount -gt 0) {
    $probeDir = Join-Path $outDirAbs "vivado_probe"
    $probeLog = Join-Path $outDirAbs "vivado_probe_step.log"
    $probeExit = Invoke-LoggedStep -Name "vivado_probe" -LogPath $probeLog -Arguments @(
      "-NoProfile", "-ExecutionPolicy", "Bypass",
      "-File", "scripts\probe_vivado_hw_targets.ps1",
      "-OutputDir", $probeDir
    )
    $steps.vivado_probe = [ordered]@{ exit = $probeExit; log = $probeLog; output_dir = $probeDir }
  } else {
    $steps.vivado_probe = [ordered]@{
      exit = "skipped"
      reason = "USB known JTAG candidate count is 0; use -ForceVivadoProbe to run Vivado anyway"
      output_dir = ""
    }
  }

  $preLog = Join-Path $outDirAbs "precondition_summary_step.log"
  $preArgs = @(
    "W8A12_3lane\tools\summarize_jtag_precondition.py",
    "--usb-json", $usbJson,
    "--out-dir", $preconditionOutAbs
  )
  if ($probeDir -ne "") {
    $preArgs += @("--vivado-probe-dir", $probeDir)
  }
  Write-Host "W8A12_RECOVERY_STEP_BEGIN=precondition"
  Write-Host "W8A12_RECOVERY_STEP_LOG=$preLog"
  $oldPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    python @preArgs *>&1 | Tee-Object -FilePath $preLog
    $preExit = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } elseif ($?) { 0 } else { 1 }
  } finally {
    $ErrorActionPreference = $oldPreference
  }
  Write-Host "W8A12_RECOVERY_STEP_EXIT_precondition=$preExit"
  $preJson = Join-Path $preconditionOutAbs "summary.json"
  $preStatus = "UNKNOWN"
  $targetCount = "not_checked"
  if (Test-Path $preJson) {
    $preData = Read-JsonFile $preJson
    $preStatus = [string]$preData.status
    $targetCount = $preData.vivado_target_count
  }
  $steps.precondition = [ordered]@{ exit = $preExit; log = $preLog; output_dir = $preconditionOutAbs; status = $preStatus }

  if ($RunStageHashAcceptance -and $preStatus -eq "READY") {
    $acceptDir = Join-Path $outDirAbs "stagehash_acceptance"
    $acceptLog = Join-Path $outDirAbs "stagehash_acceptance_step.log"
    $acceptExit = Invoke-LoggedStep -Name "stagehash_acceptance" -LogPath $acceptLog -Arguments @(
      "-NoProfile", "-ExecutionPolicy", "Bypass",
      "-File", "scripts\run_w8a12_stagehash_true2x2_acceptance.ps1",
      "-OutputDir", $acceptDir
    )
    $steps.stagehash_acceptance = [ordered]@{ exit = $acceptExit; log = $acceptLog; output_dir = $acceptDir }
  } elseif ($RunStageHashAcceptance) {
    $steps.stagehash_acceptance = [ordered]@{
      exit = "skipped"
      reason = "JTAG precondition is not READY"
      output_dir = ""
    }
  }

  $status = if ($preStatus -eq "READY") { "READY" } else { "BLOCKED" }
  $summary = [ordered]@{
    status = $status
    output_dir = $outDirAbs
    precondition_summary = $preconditionOutAbs
    usb_known_jtag_candidate_count = $knownCount
    vivado_target_count = $targetCount
    vivado_probe_skipped = [bool]$SkipVivadoProbe
    run_stagehash_acceptance_requested = [bool]$RunStageHashAcceptance
    steps = $steps
  }
  $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryJson -Encoding UTF8

  $lines = @(
    "# W8A12 Board Recovery Preflight",
    "",
    "Status: $status",
    "",
    "| Field | Value |",
    "| --- | --- |",
    "| USB known JTAG candidate count | ``$knownCount`` |",
    "| Vivado target count | ``$targetCount`` |",
    "| Vivado probe skipped | ``$([bool]$SkipVivadoProbe)`` |",
    "| precondition summary | ``$preconditionOutAbs`` |",
    "| summary JSON | ``$summaryJson`` |",
    "",
    "## Next Step",
    ""
  )
  if ($status -eq "READY") {
    $lines += "Run the stage-hash true2x2 acceptance wrapper, or rerun this preflight with `-RunStageHashAcceptance`."
  } else {
    $lines += "Restore board power/cable/JTAG mode/driver until a known JTAG device is online and Vivado reports at least one hardware target."
  }
  Set-Content -Path $summaryMd -Value $lines -Encoding UTF8

  Write-Host "W8A12_BOARD_RECOVERY_PREFLIGHT_SUMMARY_JSON=$summaryJson"
  Write-Host "W8A12_BOARD_RECOVERY_PREFLIGHT_SUMMARY_MD=$summaryMd"
  Write-Host "W8A12_BOARD_RECOVERY_PREFLIGHT_STATUS=$status"

  if ($FailOnBlocked -and $status -ne "READY") {
    exit 1
  }
} finally {
  Pop-Location
}
