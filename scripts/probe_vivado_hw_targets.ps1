param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [string]$OutputDir = "board_runs\vivado_hw_target_probe",
  [switch]$PreCleanVivado = $true,
  [switch]$PrelaunchCsServer = $false
)

$ErrorActionPreference = "Stop"
$PowerShellExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $PowerShellExe)) {
  throw "PowerShell executable not found: $PowerShellExe"
}
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$originalAppData = [Environment]::GetEnvironmentVariable("APPDATA", "Process")
$originalLocalAppData = [Environment]::GetEnvironmentVariable("LOCALAPPDATA", "Process")
$originalPath = [Environment]::GetEnvironmentVariable("Path", "Process")
$originalPATH = [Environment]::GetEnvironmentVariable("PATH", "Process")

function Resolve-ExternalExitCode {
  param([object]$LastExitCode, [bool]$Success)
  if ($null -ne $LastExitCode) {
    return [int]$LastExitCode
  }
  if ($Success) {
    return 0
  }
  return 1
}

function Resolve-WorkspacePath {
  param([string]$PathValue)
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

function Normalize-ProcessPathEnvironment {
  $pathValue = [Environment]::GetEnvironmentVariable("Path", "Process")
  if ([string]::IsNullOrEmpty($pathValue)) {
    $pathValue = [Environment]::GetEnvironmentVariable("PATH", "Process")
  }
  [Environment]::SetEnvironmentVariable("PATH", $null, "Process")
  if (-not [string]::IsNullOrEmpty($pathValue)) {
    [Environment]::SetEnvironmentVariable("Path", $pathValue, "Process")
  }
}

function Format-CmdArgument {
  param([string]$Value)
  if ($null -eq $Value) { return '""' }
  return '"' + ($Value -replace '"', '\"') + '"'
}

function Set-CleanVivadoUserDataEnvironment {
  param([string]$BaseDir)
  $appData = Join-Path $BaseDir "appdata_roaming"
  $localAppData = Join-Path $BaseDir "appdata_local"
  New-Item -ItemType Directory -Force -Path $appData | Out-Null
  New-Item -ItemType Directory -Force -Path $localAppData | Out-Null
  $env:APPDATA = $appData
  $env:LOCALAPPDATA = $localAppData
  Write-Host "VIVADO_ISOLATED_APPDATA=$appData"
  Write-Host "VIVADO_ISOLATED_LOCALAPPDATA=$localAppData"
}

function Get-CsServerExe {
  $candidate = Join-Path (Split-Path -Parent $VivadoBat) "unwrapped\win64.o\cs_server.exe"
  if (Test-Path $candidate) { return $candidate }
  $fromVivadoRoot = Join-Path (Split-Path -Parent (Split-Path -Parent $VivadoBat)) "bin\unwrapped\win64.o\cs_server.exe"
  if (Test-Path $fromVivadoRoot) { return $fromVivadoRoot }
  throw "cs_server.exe not found near VivadoBat: $VivadoBat"
}

function Restore-ProcessEnvironment {
  [Environment]::SetEnvironmentVariable("APPDATA", $originalAppData, "Process")
  [Environment]::SetEnvironmentVariable("LOCALAPPDATA", $originalLocalAppData, "Process")
  [Environment]::SetEnvironmentVariable("Path", $originalPath, "Process")
  [Environment]::SetEnvironmentVariable("PATH", $originalPATH, "Process")
}

Push-Location $root
try {
  Normalize-ProcessPathEnvironment
  if ($PreCleanVivado) {
    & $PowerShellExe -ExecutionPolicy Bypass -File scripts\cleanup_vivado_processes.ps1 -Force -WaitSeconds 5
    $cleanupExitCode = Resolve-ExternalExitCode $LASTEXITCODE $?
    if ($cleanupExitCode -ne 0) {
      throw "Vivado cleanup before hardware target probe failed with exit code $cleanupExitCode"
    }
  }

  $outDirAbs = Resolve-WorkspacePath $OutputDir
  New-Item -ItemType Directory -Path $outDirAbs -Force | Out-Null
  $log = Join-Path $outDirAbs "probe_vivado_hw_targets.log"
  $journal = Join-Path $outDirAbs "probe_vivado_hw_targets.jou"
  $stdoutLog = Join-Path $outDirAbs "probe_vivado_hw_targets.stdout.log"
  $stderrLog = Join-Path $outDirAbs "probe_vivado_hw_targets.stderr.log"
  $usbDiagScript = Join-Path $root "scripts\check_usb_jtag_devices.ps1"
  if (Test-Path $usbDiagScript) {
    try {
      & $PowerShellExe -ExecutionPolicy Bypass -File $usbDiagScript -OutputDir $outDirAbs
    } catch {
      Write-Host "USB_JTAG_DIAG_FAILED=$($_.Exception.Message)"
    }
  }
  $csServerProcess = $null
  if ($PrelaunchCsServer) {
    $csServerExe = Get-CsServerExe
    $csServerLog = Join-Path $outDirAbs "cs_server_prelaunch.log"
    $csArgs = @("-s", "TCP::3042", "-L", $csServerLog, "-I", "900")
    $csServerProcess = Start-Process -FilePath $csServerExe -ArgumentList $csArgs -WorkingDirectory $outDirAbs -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 3
    Write-Host "VIVADO_HW_TARGET_PRELAUNCH_CS_SERVER_EXE=$csServerExe"
    Write-Host "VIVADO_HW_TARGET_PRELAUNCH_CS_SERVER_PID=$($csServerProcess.Id)"
    Write-Host "VIVADO_HW_TARGET_PRELAUNCH_CS_SERVER_LOG=$csServerLog"
  }

  $vivadoWorkDir = Join-Path $env:TEMP "feitengspan1_vivado_hw_probe"
  New-Item -ItemType Directory -Force -Path $vivadoWorkDir | Out-Null
  Set-CleanVivadoUserDataEnvironment (Join-Path $vivadoWorkDir "vivado_user_data")
  $cmdExe = Join-Path $env:SystemRoot "System32\cmd.exe"
  if (-not (Test-Path $cmdExe)) { throw "cmd.exe not found: $cmdExe" }
  $tclScript = Join-Path $root "scripts\probe_vivado_hw_targets.tcl"
  $vivadoArgs = @("-mode", "batch", "-log", $log, "-journal", $journal, "-source", $tclScript)
  $vivadoCmd = "call {0} {1}" -f (Format-CmdArgument $VivadoBat), (($vivadoArgs | ForEach-Object { Format-CmdArgument $_ }) -join " ")

  Write-Host "VIVADO_HW_TARGET_PROBE_LOG=$log"
  Write-Host "VIVADO_HW_TARGET_PROBE_STDOUT_LOG=$stdoutLog"
  Write-Host "VIVADO_HW_TARGET_PROBE_STDERR_LOG=$stderrLog"
  Push-Location $vivadoWorkDir
  try {
    $nativeErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $cmdExe /d /s /c $vivadoCmd 1> $stdoutLog 2> $stderrLog
    $ErrorActionPreference = $nativeErrorActionPreference
  } finally {
    if ($null -ne $nativeErrorActionPreference) {
      $ErrorActionPreference = $nativeErrorActionPreference
    }
    Pop-Location
  }
  $exitCode = Resolve-ExternalExitCode $LASTEXITCODE $?
  Write-Host "VIVADO_HW_TARGET_PROBE_EXIT=$exitCode"
  if ($exitCode -ne 0) {
    if ((Test-Path $stderrLog) -and ((Get-Item $stderrLog).Length -gt 0)) {
      Write-Host "VIVADO_HW_TARGET_PROBE_STDERR_TAIL_BEGIN"
      Get-Content -Path $stderrLog -Tail 40 | ForEach-Object { Write-Host $_ }
      Write-Host "VIVADO_HW_TARGET_PROBE_STDERR_TAIL_END"
    }
    throw "Vivado hardware target probe failed with exit code $exitCode"
  }
}
finally {
  try {
    if ($null -ne $csServerProcess -and -not $csServerProcess.HasExited) {
      Stop-Process -Id $csServerProcess.Id -Force
    }
    if ($PreCleanVivado) {
      & $PowerShellExe -ExecutionPolicy Bypass -File scripts\cleanup_vivado_processes.ps1 -Force -WaitSeconds 5
    }
  } finally {
    Restore-ProcessEnvironment
    Pop-Location
  }
}
