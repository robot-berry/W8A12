param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"
$Repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_single_conv.tcl"

if (!(Test-Path $VivadoBat)) {
  throw "VivadoBat not found: $VivadoBat"
}

& $VivadoBat -mode batch -source $Tcl
if ($LASTEXITCODE -ne 0) {
  throw "Vivado simulation failed with exit code $LASTEXITCODE"
}
