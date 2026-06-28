$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}
$Tcl = Join-Path $Repo "scripts\run_vivado_sim_w8a12_spab_chain_frame.tcl"
$Tb = Join-Path $Repo "W8A12_3lane\evidence\reference\A3_tail_rgb\rtl_tail_frame_tb\tb_span_w8a12_tail_frame.sv"

Push-Location $Repo
try {
    $env:W8A12_SPAB_CHAIN_FRAME_TB = $Tb
    $env:W8A12_SPAB_CHAIN_FRAME_TOP = "tb_span_w8a12_tail_frame"
    $env:W8A12_SPAB_CHAIN_FRAME_PROJ = "vivado_w8a12_3lane_a3_tail_frame_sim"
    & $Vivado -mode batch -source $Tcl
    if ($LASTEXITCODE -ne 0) {
        throw "Vivado A3 tail frame simulation failed with exit code $LASTEXITCODE"
    }
} finally {
    Remove-Item Env:\W8A12_SPAB_CHAIN_FRAME_TB -ErrorAction SilentlyContinue
    Remove-Item Env:\W8A12_SPAB_CHAIN_FRAME_TOP -ErrorAction SilentlyContinue
    Remove-Item Env:\W8A12_SPAB_CHAIN_FRAME_PROJ -ErrorAction SilentlyContinue
    Pop-Location
}
