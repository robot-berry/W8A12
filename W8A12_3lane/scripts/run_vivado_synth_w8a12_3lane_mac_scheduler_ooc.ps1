$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}
$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.tcl"
$ReportDir = Join-Path $Repo "W8A12_3lane\evidence\resource\A4_3lane_mac_scheduler_ooc"
$VivadoLog = Join-Path $ReportDir "vivado_3lane_mac_scheduler_ooc.log"
$VivadoJournal = Join-Path $ReportDir "vivado_3lane_mac_scheduler_ooc.jou"
$UtilRpt = Join-Path $ReportDir "utilization_ooc.rpt"
$TimingRpt = Join-Path $ReportDir "timing_ooc.rpt"

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

Push-Location $Repo
try {
    & $Vivado -mode batch -log $VivadoLog -journal $VivadoJournal -source $Tcl
    if (-not (Test-Path $UtilRpt)) {
        throw "3-lane OOC did not produce utilization_ooc.rpt"
    }
    if (-not (Test-Path $TimingRpt)) {
        throw "3-lane OOC did not produce timing_ooc.rpt"
    }
} finally {
    Pop-Location
}
