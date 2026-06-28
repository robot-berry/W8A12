$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}
$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_sim_w8a12_single_out_mac_scheduler.tcl"
$Log = Join-Path $Repo "build\vivado_w8a12_single_out_mac_scheduler_sim\w8a12_single_out_mac_scheduler_sim.sim\sim_1\behav\xsim\simulate.log"

Push-Location $Repo
try {
    & $Vivado -mode batch -source $Tcl
    if (-not (Test-Path $Log)) {
        throw "Vivado single-out scheduler simulation did not produce simulate.log"
    }
    $Text = Get-Content -Raw -Encoding UTF8 $Log
    if ($Text -notmatch "PASS w8a12_single_out_mac_scheduler") {
        throw "Vivado single-out scheduler simulation did not report PASS"
    }
} finally {
    Pop-Location
}
