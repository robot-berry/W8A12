$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}

$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_accel_top.tcl"
$Log = Join-Path $Repo "build\vivado_w8a12_3lane_accel_top_sim\w8a12_3lane_accel_top_sim.sim\sim_1\behav\xsim\simulate.log"
$EvidenceDir = Join-Path $Repo "W8A12_3lane\evidence\top\accel_top_sim"
$VivadoLog = Join-Path $EvidenceDir "vivado_accel_top_sim.log"
$VivadoJournal = Join-Path $EvidenceDir "vivado_accel_top_sim.jou"
$SummaryMd = Join-Path $EvidenceDir "summary.md"
$SummaryJson = Join-Path $EvidenceDir "summary.json"

New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

Push-Location $Repo
try {
    & $Vivado -mode batch -log $VivadoLog -journal $VivadoJournal -source $Tcl
    if (-not (Test-Path $Log)) {
        throw "Vivado accel top simulation did not produce simulate.log"
    }
    $Text = Get-Content -Raw -Encoding UTF8 $Log
    if ($Text -notmatch "PASS w8a12_3lane_accel_top") {
        throw "Vivado accel top simulation did not report PASS"
    }
    $PassLine = [regex]::Match($Text, "PASS w8a12_3lane_accel_top[^\r\n]*").Value
    $Payload = [pscustomobject]@{
        status = "PASS"
        stage = "w8a12_3lane_accel_top"
        top = "tb_w8a12_3lane_accel_top"
        pass_line = $PassLine
        simulate_log = $Log
        vivado_log = $VivadoLog
        vivado_journal = $VivadoJournal
        expected = "control/status shell sequences load, conv1, 6 SPAB blocks, tail, write and latches done/irq"
    }
    $Payload | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -Path $SummaryJson
    @(
        "# Accelerator Top Simulation",
        "",
        "Status: PASS",
        "",
        "| Item | Value |",
        "| --- | --- |",
        "| top | tb_w8a12_3lane_accel_top |",
        "| pass_line | $PassLine |",
        "| simulate_log | $Log |",
        "| vivado_log | $VivadoLog |",
        "| expected | control/status shell sequences load, conv1, 6 SPAB blocks, tail, write and latches done/irq |",
        ""
    ) | Set-Content -Encoding UTF8 -Path $SummaryMd
} finally {
    Pop-Location
}
