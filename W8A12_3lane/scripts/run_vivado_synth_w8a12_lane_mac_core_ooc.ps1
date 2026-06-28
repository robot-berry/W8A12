$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}
$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_synth_w8a12_lane_mac_core_ooc.tcl"
$Report = Join-Path $Repo "W8A12_3lane\evidence\resource\A4_lane_mac_core_ooc\utilization_ooc.rpt"
$GateJson = Join-Path $Repo "W8A12_3lane\evidence\resource\A4_lane_mac_core_ooc\xc7z045_resource_gate.json"

Push-Location $Repo
try {
    & $Vivado -mode batch -source $Tcl
    if ($LASTEXITCODE -ne 0) {
        throw "Vivado OOC synthesis failed with exit code $LASTEXITCODE"
    }
    python tools\check_vivado_zc706_resource_gate.py $Report --json-out $GateJson
    if ($LASTEXITCODE -ne 0) {
        throw "XC7Z045 resource gate failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}
