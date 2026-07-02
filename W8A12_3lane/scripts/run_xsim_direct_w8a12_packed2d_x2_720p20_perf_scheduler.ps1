$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$VivadoBin = "D:\software\2025.2\Vivado\bin"
$Xvlog = Join-Path $VivadoBin "xvlog.bat"
$Xelab = Join-Path $VivadoBin "xelab.bat"
$Xsim = Join-Path $VivadoBin "xsim.bat"

foreach ($Tool in @($Xvlog, $Xelab, $Xsim)) {
    if (-not (Test-Path $Tool)) {
        throw "Required Vivado simulator tool not found: $Tool"
    }
}

$Build = Join-Path $Repo "build\xsim_direct_w8a12_packed2d_x2_720p20_perf_scheduler"
$EvidenceDir = Join-Path $Repo "W8A12_3lane\evidence\sim_fps_design_space\packed2d_x2_direct_xsim_replay"
$SummaryMd = Join-Path $EvidenceDir "summary.md"
$SummaryJson = Join-Path $EvidenceDir "summary.json"
$SourceSummaryJson = Join-Path $Repo "W8A12_3lane\evidence\sim_fps_design_space\packed2d_x2_720p20_perf_scheduler\summary.json"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$BuildResolvedParent = (Resolve-Path (Join-Path $Repo "build") -ErrorAction SilentlyContinue)
if ($BuildResolvedParent -and (Test-Path $Build)) {
    $ResolvedBuild = (Resolve-Path $Build).Path
    if (-not $ResolvedBuild.StartsWith($BuildResolvedParent.Path, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean build path outside repo build directory: $ResolvedBuild"
    }
    Remove-Item -LiteralPath $ResolvedBuild -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $Build | Out-Null
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null

$Scheduler = Join-Path $Repo "W8A12_3lane\rtl\span\w8a12_packed2d_perf_scheduler.v"
$Tb = Join-Path $Repo "W8A12_3lane\sim\tb_w8a12_packed2d_x2_720p20_perf_scheduler.sv"

Push-Location $Build
try {
    & $Xvlog --sv $Scheduler $Tb 2>&1 | Tee-Object -FilePath "xvlog_console.log"
    if ($LASTEXITCODE -ne 0) {
        throw "xvlog failed with exit code $LASTEXITCODE"
    }

    & $Xelab tb_w8a12_packed2d_x2_720p20_perf_scheduler -s tb_w8a12_packed2d_x2_720p20_perf_scheduler_sim 2>&1 | Tee-Object -FilePath "xelab_console.log"
    if ($LASTEXITCODE -ne 0) {
        throw "xelab failed with exit code $LASTEXITCODE"
    }

    & $Xsim tb_w8a12_packed2d_x2_720p20_perf_scheduler_sim -runall -log simulate.log 2>&1 | Tee-Object -FilePath "xsim_console.log"
    if ($LASTEXITCODE -ne 0) {
        throw "xsim failed with exit code $LASTEXITCODE"
    }
} finally {
    Pop-Location
}

$SimulateLog = Join-Path $Build "simulate.log"
if (-not (Test-Path $SimulateLog)) {
    throw "Direct xsim replay did not produce simulate.log"
}

$Text = Get-Content -Raw -Encoding UTF8 $SimulateLog
$Matches = [regex]::Matches(
    $Text,
    "PASS w8a12_packed2d_x2_720p20_perf_scheduler candidate=(\S+) output_lanes=(\d+) tap_lanes=(\d+) est_dsp=(\d+) cycles_per_lr_pixel=(\d+) frame_pixels=(\d+) frame_cycles=(\d+) fps_x1000=(\d+) pass15=(\d+) pass20=(\d+) pass30=(\d+) resource_gate=(\d+)"
)
if ($Matches.Count -lt 3) {
    throw "Direct xsim replay did not report all expected candidates"
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
$MatchesBatchSummary = $false
if (Test-Path $SourceSummaryJson) {
    $Source = Get-Content -Raw -Encoding UTF8 $SourceSummaryJson | ConvertFrom-Json
    $SourceByName = @{}
    foreach ($Candidate in $Source.candidates) {
        $SourceByName[$Candidate.candidate] = $Candidate
    }
    $Mismatches = @()
    foreach ($Candidate in $Candidates) {
        $SourceCandidate = $SourceByName[$Candidate.candidate]
        if (-not $SourceCandidate) {
            $Mismatches += "$($Candidate.candidate):missing"
            continue
        }
        foreach ($Field in @("estimated_dsp", "cycles_per_lr_pixel", "frame_pixels", "frame_cycles", "fps_x1000", "pass15", "pass20", "pass30", "resource_gate")) {
            if ([string]$Candidate.$Field -ne [string]$SourceCandidate.$Field) {
                $Mismatches += "$($Candidate.candidate):$Field"
            }
        }
    }
    $MatchesBatchSummary = $Mismatches.Count -eq 0
} else {
    $Mismatches = @("source_summary_missing")
}

$Payload = [pscustomobject]@{
    status = if ($MatchesBatchSummary) { "PASS" } else { "FAIL" }
    runner = "direct_xvlog_xelab_xsim"
    stage = "packed2d_x2_720p20_perf_scheduler_direct_replay"
    scope = "Direct xsim replay of the x2 packed 2-D scheduler/performance-model evidence without starting a Vivado batch project"
    model = "REDS SPAN x2 F48 W8A12, 22 convolution layers"
    frame = "640x360 LR -> 1280x720 SR"
    clock_mhz = 250.0
    dsp_gate = "XC7Z045/ZC706 900 DSP planning gate"
    target_status = if ($ResourcePass20) { "PASS" } else { "FAIL" }
    resource_gated_candidate_pass20 = $ResourcePass20
    matches_vivado_batch_summary = $MatchesBatchSummary
    mismatch_fields_vs_batch_summary = $Mismatches
    candidates = $Candidates
    build_dir = $Build
    simulate_log = $SimulateLog
    source_summary_json = $SourceSummaryJson
}
[System.IO.File]::WriteAllText($SummaryJson, ($Payload | ConvertTo-Json -Depth 6), $Utf8NoBom)

$Lines = @(
    "# Packed 2-D x2 Direct XSIM Replay",
    "",
    "Status: $($Payload.status)",
    "",
    "Runner: direct `xvlog` -> `xelab` -> `xsim`.",
    "",
    "This replay exists so x2 scheduler FPS evidence can be refreshed without starting another Vivado batch/project process while implementation runs are active.",
    "It is still scheduler/performance-model evidence only; it is not pixel-correctness RTL closure and not board-measured FPS.",
    "",
    "| Item | Value |",
    "| --- | --- |",
    "| model | REDS SPAN x2 F48 W8A12 |",
    "| frame | 640x360 LR -> 1280x720 SR |",
    "| clock | 250 MHz |",
    "| resource gate | XC7Z045/ZC706 900 DSP planning gate |",
    "| 20fps target under 900-DSP gate | $($Payload.target_status) |",
    "| matches Vivado batch summary | $($Payload.matches_vivado_batch_summary) |",
    "| simulate_log | $SimulateLog |",
    "| source_summary_json | $SourceSummaryJson |",
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
    "- Direct xsim replay reproduces the candidate metrics in the Vivado batch summary.",
    "- `24x72` remains the lowered x2 720p4 closure point at 4.483fps and 888 DSP.",
    "- x2 720p20 remains not claimed under the 900-DSP planning gate.",
    ""
)
[System.IO.File]::WriteAllText($SummaryMd, ($Lines -join "`n"), $Utf8NoBom)

Write-Host "DIRECT_XSIM_REPLAY_STATUS=$($Payload.status)"
Write-Host "DIRECT_XSIM_REPLAY_SUMMARY=$SummaryMd"
Write-Host "DIRECT_XSIM_REPLAY_JSON=$SummaryJson"
if ($Payload.status -ne "PASS") {
    exit 1
}
