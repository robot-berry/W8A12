$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}
$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_single_block.tcl"

Push-Location $Repo
try {
    & $Vivado -mode batch -source $Tcl
    if ($LASTEXITCODE -ne 0) {
        throw "Vivado simulation failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}
