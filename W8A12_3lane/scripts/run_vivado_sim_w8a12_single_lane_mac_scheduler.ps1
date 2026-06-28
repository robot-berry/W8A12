$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}
$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_sim_w8a12_single_lane_mac_scheduler.tcl"
$Log = Join-Path $Repo "build\vivado_w8a12_single_lane_mac_scheduler_sim\w8a12_single_lane_mac_scheduler_sim.sim\sim_1\behav\xsim\simulate.log"
$EvidenceDir = Join-Path $Repo "W8A12_3lane\evidence\resource\A4_single_lane_mac_scheduler"
$VivadoLog = Join-Path $EvidenceDir "vivado_single_lane_mac_scheduler.log"
$VivadoJournal = Join-Path $EvidenceDir "vivado_single_lane_mac_scheduler.jou"
$SummaryMd = Join-Path $EvidenceDir "single_lane_scheduler_sim_summary.md"
$SummaryJson = Join-Path $EvidenceDir "single_lane_scheduler_sim_summary.json"

New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

Push-Location $Repo
try {
    & $Vivado -mode batch -log $VivadoLog -journal $VivadoJournal -source $Tcl
    if (-not (Test-Path $Log)) {
        throw "Vivado single-lane scheduler simulation did not produce simulate.log"
    }
    $Text = Get-Content -Raw -Encoding UTF8 $Log
    if ($Text -notmatch "PASS w8a12_single_lane_mac_scheduler") {
        throw "Vivado single-lane scheduler simulation did not report PASS"
    }

    $PassLine = [regex]::Match($Text, "PASS w8a12_single_lane_mac_scheduler[^\r\n]*").Value
    $Payload = [pscustomobject]@{
        status = "PASS"
        stage = "A4_single_lane_mac_scheduler"
        top = "tb_w8a12_single_lane_mac_scheduler"
        pass_line = $PassLine
        simulate_log = $Log
        vivado_log = $VivadoLog
        vivado_journal = $VivadoJournal
        expected = "lane0 channels 0..15 bit-exact against A0 full48_output.txt"
    }
    $Payload | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -Path $SummaryJson
    @(
        "# A4 Single-Lane MAC Scheduler Simulation",
        "",
        "Status: PASS",
        "",
        "| Item | Value |",
        "| --- | --- |",
        "| top | tb_w8a12_single_lane_mac_scheduler |",
        "| pass_line | $PassLine |",
        "| simulate_log | $Log |",
        "| vivado_log | $VivadoLog |",
        "| expected | lane0 channels 0..15 bit-exact against A0 full48_output.txt |",
        ""
    ) | Set-Content -Encoding UTF8 -Path $SummaryMd
} finally {
    Pop-Location
}
