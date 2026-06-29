param(
  [switch]$Force,
  [int]$WaitSeconds = 10
)

$ErrorActionPreference = "Stop"

function Get-VivadoProcesses {
  $names = @(
    "vivado",
    "vivado_lab",
    "parallel_synth_helper",
    "rdi_xsdb",
    "hw_server",
    "cs_server",
    "xelab",
    "xsim",
    "xvlog",
    "xvhdl"
  )
  @(Get-Process -Name $names -ErrorAction SilentlyContinue | Sort-Object ProcessName, Id)
}

$before = Get-VivadoProcesses
if ($before.Count -eq 0) {
  Write-Host "VIVADO_CLEANUP_BEFORE_COUNT=0"
  Write-Host "VIVADO_CLEANUP_AFTER_COUNT=0"
  Write-Host "VIVADO_CLEANUP_CLEAN=1"
  exit 0
}

Write-Host "VIVADO_CLEANUP_BEFORE_COUNT=$($before.Count)"
foreach ($p in $before) {
  Write-Host "VIVADO_CLEANUP_PROCESS PID=$($p.Id) NAME=$($p.ProcessName)"
}

foreach ($p in $before) {
  try {
    if ($Force) {
      Stop-Process -Id $p.Id -Force -ErrorAction Stop
    } else {
      Stop-Process -Id $p.Id -ErrorAction Stop
    }
  } catch {
    Write-Warning "Failed to stop PID=$($p.Id) NAME=$($p.ProcessName): $($_.Exception.Message)"
  }
}

if ($WaitSeconds -gt 0) {
  Start-Sleep -Seconds $WaitSeconds
}

$after = Get-VivadoProcesses
Write-Host "VIVADO_CLEANUP_AFTER_COUNT=$($after.Count)"
foreach ($p in $after) {
  Write-Host "VIVADO_CLEANUP_REMAINING PID=$($p.Id) NAME=$($p.ProcessName)"
}

if ($after.Count -ne 0) {
  Write-Host "VIVADO_CLEANUP_CLEAN=0"
  throw "Vivado cleanup failed; residual Vivado-related processes remain"
}

Write-Host "VIVADO_CLEANUP_CLEAN=1"
