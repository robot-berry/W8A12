param(
  [string]$XsctBat = "D:\software\2025.2\Vitis\bin\xsct.bat",
  [string]$PsuInitTcl,
  [string]$OutputDir = "board_runs\psu_init_only\latest"
)

$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

Push-Location $Repo
try {
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_xsct_psu_init_only.ps1 `
    -XsctBat $XsctBat `
    -PsuInitTcl $PsuInitTcl `
    -OutputDir $OutputDir
} finally {
  Pop-Location
}
