$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}
$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_mac_scheduler.tcl"
$Log = Join-Path $Repo "build\vivado_w8a12_3lane_mac_scheduler_sim\w8a12_3lane_mac_scheduler_sim.sim\sim_1\behav\xsim\simulate.log"
$EvidenceDir = Join-Path $Repo "W8A12_3lane\evidence\resource\A4_3lane_mac_scheduler"
$VivadoLog = Join-Path $EvidenceDir "vivado_3lane_mac_scheduler.log"
$VivadoJournal = Join-Path $EvidenceDir "vivado_3lane_mac_scheduler.jou"
$SummaryMd = Join-Path $EvidenceDir "a4_3lane_sim_summary.md"
$SummaryJson = Join-Path $EvidenceDir "a4_3lane_sim_summary.json"

New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

Push-Location $Repo
try {
    & $Vivado -mode batch -log $VivadoLog -journal $VivadoJournal -source $Tcl
    if (-not (Test-Path $Log)) {
        throw "Vivado 3-lane MAC scheduler simulation did not produce simulate.log"
    }
    $Text = Get-Content -Raw -Encoding UTF8 $Log
    if ($Text -notmatch "PASS w8a12_3lane_mac_scheduler") {
        throw "Vivado 3-lane MAC scheduler simulation did not report PASS"
    }

    $PassLine = [regex]::Match($Text, "PASS w8a12_3lane_mac_scheduler[^\r\n]*").Value
    $PerfMatch = [regex]::Match($PassLine, "pixels=(\d+)\s+channels=(\d+)(?:\s+accepted=(\d+)\s+cycles=(\d+)\s+cycles_per_pixel_ceil=(\d+))?")
    $Perf = [ordered]@{}
    if ($PerfMatch.Success) {
        $Perf["pixels"] = [int]$PerfMatch.Groups[1].Value
        $Perf["channels"] = [int]$PerfMatch.Groups[2].Value
        if ($PerfMatch.Groups[3].Success) {
            $Perf["accepted_pixels"] = [int]$PerfMatch.Groups[3].Value
            $Perf["single_stage_cycles"] = [int]$PerfMatch.Groups[4].Value
            $Perf["single_stage_cycles_per_pixel_ceil"] = [int]$PerfMatch.Groups[5].Value
            $Perf["clock_mhz_reference"] = 100.0
            $Perf["single_stage_pixels_per_second_at_100mhz"] = [math]::Round(100000000.0 / [double]$Perf["single_stage_cycles_per_pixel_ceil"], 3)
        }
    }
    $Payload = [pscustomobject]@{
        status = "PASS"
        stage = "A4_3lane_mac_scheduler"
        top = "tb_w8a12_3lane_mac_scheduler"
        pass_line = $PassLine
        performance = $Perf
        simulate_log = $Log
        vivado_log = $VivadoLog
        vivado_journal = $VivadoJournal
        expected = "lane0/1/2 stitched channels 0..47 bit-exact against A0 full48_output.txt"
    }
    $Payload | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -Path $SummaryJson
    @(
        "# A4 3-Lane MAC Scheduler Simulation",
        "",
        "Status: PASS",
        "",
        "| Item | Value |",
        "| --- | --- |",
        "| top | tb_w8a12_3lane_mac_scheduler |",
        "| pass_line | $PassLine |",
        "| single_stage_cycles | $($Perf["single_stage_cycles"]) |",
        "| single_stage_cycles_per_pixel_ceil | $($Perf["single_stage_cycles_per_pixel_ceil"]) |",
        "| single_stage_pixels_per_second_at_100mhz | $($Perf["single_stage_pixels_per_second_at_100mhz"]) |",
        "| simulate_log | $Log |",
        "| vivado_log | $VivadoLog |",
        "| expected | lane0/1/2 stitched channels 0..47 bit-exact against A0 full48_output.txt |",
        ""
    ) | Set-Content -Encoding UTF8 -Path $SummaryMd
} finally {
    Pop-Location
}
