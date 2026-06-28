$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}

$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_accel_top_ooc.tcl"
$ReportDir = Join-Path $Repo "W8A12_3lane\evidence\top\accel_top_ooc"
$VivadoLog = Join-Path $ReportDir "vivado_accel_top_ooc.log"
$VivadoJournal = Join-Path $ReportDir "vivado_accel_top_ooc.jou"
$UtilRpt = Join-Path $ReportDir "utilization_ooc.rpt"
$TimingRpt = Join-Path $ReportDir "timing_ooc.rpt"

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

Push-Location $Repo
try {
    & $Vivado -mode batch -log $VivadoLog -journal $VivadoJournal -source $Tcl
    if (-not (Test-Path $UtilRpt)) {
        throw "accel top OOC did not produce utilization_ooc.rpt"
    }
    if (-not (Test-Path $TimingRpt)) {
        throw "accel top OOC did not produce timing_ooc.rpt"
    }
} finally {
    Pop-Location
}
