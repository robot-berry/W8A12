$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}

$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_sim_w8a12_packed2d_x2_720p20_perf_scheduler.tcl"
$Log = Join-Path $Repo "build\vivado_w8a12_packed2d_x2_720p20_perf_scheduler_sim\w8a12_packed2d_x2_720p20_perf_scheduler_sim.sim\sim_1\behav\xsim\simulate.log"
$EvidenceDir = Join-Path $Repo "W8A12_3lane\evidence\sim_fps_design_space\packed2d_x2_720p20_perf_scheduler"
$VivadoLog = Join-Path $EvidenceDir "vivado_packed2d_x2_720p20_perf_scheduler.log"
$VivadoJournal = Join-Path $EvidenceDir "vivado_packed2d_x2_720p20_perf_scheduler.jou"
$SummaryMd = Join-Path $EvidenceDir "summary.md"
$SummaryJson = Join-Path $EvidenceDir "summary.json"

New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

Push-Location $Repo
try {
    & $Vivado -mode batch -log $VivadoLog -journal $VivadoJournal -source $Tcl
    if (-not (Test-Path $Log)) {
        throw "Vivado packed 2-D x2 720p20 performance simulation did not produce simulate.log"
    }

    $Text = Get-Content -Raw -Encoding UTF8 $Log
    $Matches = [regex]::Matches(
        $Text,
        "PASS w8a12_packed2d_x2_720p20_perf_scheduler candidate=(\S+) output_lanes=(\d+) tap_lanes=(\d+) est_dsp=(\d+) cycles_per_lr_pixel=(\d+) frame_pixels=(\d+) frame_cycles=(\d+) fps_x1000=(\d+) pass15=(\d+) pass20=(\d+) pass30=(\d+) resource_gate=(\d+)"
    )
    if ($Matches.Count -lt 3) {
        throw "Vivado packed 2-D x2 720p20 performance simulation did not report all candidates"
    }

    $Candidates = @()
    foreach ($Match in $Matches) {
        $FpsX1000 = [int64]$Match.Groups[8].Value
        $Candidates += [pscustomobject]@{
            candidate = $Match.Groups[1].Value
            output_lanes = [int]$Match.Groups[2].Value
            tap_lanes = [int]$Match.Groups[3].Value
            estimated_dsp = [int]$Match.Groups[4].Value
            cycles_per_lr_pixel = [int]$Match.Groups[5].Value
            frame_pixels = [int]$Match.Groups[6].Value
            frame_cycles = [int64]$Match.Groups[7].Value
            fps_x1000 = $FpsX1000
            fps = [math]::Round($FpsX1000 / 1000.0, 3)
            pass15 = ([int]$Match.Groups[9].Value) -eq 1
            pass20 = ([int]$Match.Groups[10].Value) -eq 1
            pass30 = ([int]$Match.Groups[11].Value) -eq 1
            resource_gate = ([int]$Match.Groups[12].Value) -eq 1
        }
    }

    $ResourcePass20 = ($Candidates | Where-Object { $_.resource_gate -and $_.pass20 }).Count -gt 0
    $AnyPass20 = ($Candidates | Where-Object { $_.pass20 }).Count -gt 0
    $Payload = [pscustomobject]@{
        status = "PASS"
        target_status = if ($ResourcePass20) { "PASS" } else { "FAIL" }
        stage = "packed2d_x2_720p20_perf_scheduler"
        scope = "x2 720p 20fps simulation evidence for W8A12 performance sizing"
        model = "REDS SPAN x2 F48 W8A12, 22 convolution layers"
        frame = "640x360 LR -> 1280x720 SR"
        clock_mhz = 250.0
        dsp_gate = "XC7Z045/ZC706 900 DSP planning gate"
        tail_out_channels = 12
        any_candidate_pass20 = $AnyPass20
        resource_gated_candidate_pass20 = $ResourcePass20
        candidates = $Candidates
        simulate_log = $Log
        vivado_log = $VivadoLog
        vivado_journal = $VivadoJournal
    }
    $Payload | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -Path $SummaryJson

    $Lines = @(
        "# Packed 2-D x2 720p20 FPS Scheduler Simulation",
        "",
        "Status: PASS",
        "",
        "20fps target under 900-DSP gate: $($Payload.target_status)",
        "",
        "This is a scheduler/performance-model xsim result for the x2 route. It is not a pixel-correctness simulation and not a board-measured FPS report.",
        "",
        "| Item | Value |",
        "| --- | --- |",
        "| model | REDS SPAN x2 F48 W8A12 |",
        "| layers | 22 convolution layers |",
        "| frame | 640x360 LR -> 1280x720 SR |",
        "| clock | 250 MHz |",
        "| resource gate | XC7Z045/ZC706 900 DSP planning gate |",
        "| tail output channels | 12 |",
        "| simulate_log | $Log |",
        "",
        "## Candidates",
        "",
        "| Candidate | Output lanes | Tap lanes | Est. DSP | Resource gate | Cycles/LR pixel | Frame cycles | FPS @250MHz | 15fps | 20fps | 30fps |",
        "| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | --- | --- | --- |"
    )
    foreach ($Candidate in $Candidates) {
        $Gate = if ($Candidate.resource_gate) { "PASS" } else { "FAIL" }
        $P15 = if ($Candidate.pass15) { "PASS" } else { "FAIL" }
        $P20 = if ($Candidate.pass20) { "PASS" } else { "FAIL" }
        $P30 = if ($Candidate.pass30) { "PASS" } else { "FAIL" }
        $Lines += "| $($Candidate.candidate) | $($Candidate.output_lanes) | $($Candidate.tap_lanes) | $($Candidate.estimated_dsp) | $Gate | $($Candidate.cycles_per_lr_pixel) | $($Candidate.frame_cycles) | $($Candidate.fps) | $P15 | $P20 | $P30 |"
    }
    $Lines += @(
        "",
        "## Interpretation",
        "",
        "- The 900-DSP resource-gated candidates do not reach x2 720p20 at 250 MHz.",
        "- Even the non-gated 48x144 sizing point remains below 20fps at 250 MHz and exceeds the ZC706/XC7Z045 DSP planning gate.",
        "- Therefore x2 720p20 is not closed by the current full W8A12/F48 packed 2-D plan. Closing this target needs a smaller student model, higher resource budget/clock, or a more aggressive architecture than this planning gate permits.",
        ""
    )
    $Lines | Set-Content -Encoding UTF8 -Path $SummaryMd
} finally {
    Pop-Location
}
