$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$Vivado = "D:\software\2025.2\Vivado\bin\vivado.bat"
if (-not (Test-Path $Vivado)) {
    $Vivado = "vivado"
}

$Tcl = Join-Path $Repo "W8A12_3lane\scripts\run_vivado_sim_w8a12_packed2d_perf_scheduler.tcl"
$Log = Join-Path $Repo "build\vivado_w8a12_packed2d_perf_scheduler_sim\w8a12_packed2d_perf_scheduler_sim.sim\sim_1\behav\xsim\simulate.log"
$EvidenceDir = Join-Path $Repo "W8A12_3lane\evidence\sim_fps_design_space\packed2d_perf_scheduler"
$VivadoLog = Join-Path $EvidenceDir "vivado_packed2d_perf_scheduler.log"
$VivadoJournal = Join-Path $EvidenceDir "vivado_packed2d_perf_scheduler.jou"
$SummaryMd = Join-Path $EvidenceDir "summary.md"
$SummaryJson = Join-Path $EvidenceDir "summary.json"

New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

Push-Location $Repo
try {
    & $Vivado -mode batch -log $VivadoLog -journal $VivadoJournal -source $Tcl
    if (-not (Test-Path $Log)) {
        throw "Vivado packed 2-D performance simulation did not produce simulate.log"
    }

    $Text = Get-Content -Raw -Encoding UTF8 $Log
    $Matches = [regex]::Matches(
        $Text,
        "PASS w8a12_packed2d_perf_scheduler candidate=(\S+) output_lanes=(\d+) tap_lanes=(\d+) est_dsp=(\d+) cycles_per_lr_pixel=(\d+) frame_pixels=(\d+) frame_cycles=(\d+) fps_x1000=(\d+) pass15=(\d+) pass20=(\d+) pass30=(\d+)"
    )
    if ($Matches.Count -lt 2) {
        throw "Vivado packed 2-D performance simulation did not report both PASS candidates"
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
        }
    }

    $Status = if (($Candidates | Where-Object { $_.pass15 -and $_.estimated_dsp -le 900 }).Count -gt 0) { "PASS" } else { "FAIL" }
    $Payload = [pscustomobject]@{
        status = $Status
        stage = "packed2d_perf_scheduler"
        scope = "720p x4 FPS simulation gate for next W8A12 performance engine"
        model = "REDS SPAN x4 F48 W8A12, 22 convolution layers"
        frame = "320x180 LR -> 1280x720 SR"
        clock_mhz = 250.0
        dsp_gate = "XC7Z045/ZC706 900 DSP planning gate"
        candidates = $Candidates
        simulate_log = $Log
        vivado_log = $VivadoLog
        vivado_journal = $VivadoJournal
    }
    $Payload | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -Path $SummaryJson

    $Lines = @(
        "# Packed 2-D FPS Scheduler Simulation",
        "",
        "Status: $Status",
        "",
        "This is the 720p x4 FPS simulation gate for the next W8A12 performance-engine route. It is a scheduler-level xsim result, not a pixel-correctness simulation and not a board-measured FPS report.",
        "",
        "| Item | Value |",
        "| --- | --- |",
        "| model | REDS SPAN x4 F48 W8A12 |",
        "| layers | 22 convolution layers |",
        "| frame | 320x180 LR -> 1280x720 SR |",
        "| clock | 250 MHz |",
        "| resource gate | XC7Z045/ZC706 900 DSP planning gate |",
        "| simulate_log | $Log |",
        "",
        "## Candidates",
        "",
        "| Candidate | Output lanes | Tap lanes | Est. DSP | Cycles/LR pixel | Frame cycles | FPS @250MHz | 15fps | 20fps | 30fps |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |"
    )
    foreach ($Candidate in $Candidates) {
        $P15 = if ($Candidate.pass15) { "PASS" } else { "FAIL" }
        $P20 = if ($Candidate.pass20) { "PASS" } else { "FAIL" }
        $P30 = if ($Candidate.pass30) { "PASS" } else { "FAIL" }
        $Lines += "| $($Candidate.candidate) | $($Candidate.output_lanes) | $($Candidate.tap_lanes) | $($Candidate.estimated_dsp) | $($Candidate.cycles_per_lr_pixel) | $($Candidate.frame_cycles) | $($Candidate.fps) | $P15 | $P20 | $P30 |"
    }
    $Lines += @(
        "",
        "## Interpretation",
        "",
        "- `24x64` is the minimum-resource 15fps candidate found under the 900-DSP planning gate; it has almost no timing/overhead margin.",
        "- `24x72` gives more FPS margin but uses nearly the full 900-DSP gate.",
        "- This closes the FPS target only at scheduler/performance-model level. The remaining engineering work is to implement the packed 2-D engine, memory banking, and line-buffer/halo reuse RTL, then re-run correctness and OOC/PPA gates.",
        ""
    )
    $Lines | Set-Content -Encoding UTF8 -Path $SummaryMd
} finally {
    Pop-Location
}
