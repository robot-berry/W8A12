param(
    [string]$RunId = "",
    [switch]$SkipVivado,
    [switch]$SkipX2,
    [switch]$ContinueOnError
)

$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($RunId -eq "") {
    $RunId = Get-Date -Format "yyyyMMdd_HHmmss"
}

$RunDir = Join-Path $Repo "W8A12_3lane\evidence\delivery_runs\$RunId"
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$Results = @()

function Invoke-GateStep {
    param(
        [string]$Name,
        [scriptblock]$Action,
        [string[]]$ExpectedFiles = @(),
        [string]$ExpectedText = "",
        [int[]]$AllowedExitCodes = @(0)
    )

    $StepDir = Join-Path $RunDir $Name
    New-Item -ItemType Directory -Force -Path $StepDir | Out-Null
    $Stdout = Join-Path $StepDir "stdout.txt"
    $Stderr = Join-Path $StepDir "stderr.txt"
    $Status = "PASS"
    $Message = ""

    try {
        Push-Location $Repo
        try {
            $global:LASTEXITCODE = 0
            & $Action *> $Stdout
            if ($AllowedExitCodes -notcontains $global:LASTEXITCODE) {
                throw "command exited with code $global:LASTEXITCODE"
            }
        } finally {
            Pop-Location
        }

        foreach ($File in $ExpectedFiles) {
            $Full = Join-Path $Repo $File
            if (-not (Test-Path $Full)) {
                throw "missing expected file: $File"
            }
            if ($ExpectedText -ne "") {
                $Text = Get-Content -Raw -Encoding UTF8 $Full
                if ($Text -notmatch [regex]::Escape($ExpectedText)) {
                    throw "expected text not found in ${File}: $ExpectedText"
                }
            }
        }
    } catch {
        $Status = "FAIL"
        $Message = $_.Exception.Message
        Set-Content -Encoding UTF8 -Path $Stderr -Value $Message
        if (-not $ContinueOnError) {
            $script:Results += [pscustomobject]@{
                name = $Name
                status = $Status
                message = $Message
            }
            Write-GateSummary
            throw
        }
    }

    $script:Results += [pscustomobject]@{
        name = $Name
        status = $Status
        message = $Message
    }
}

function Write-GateSummary {
    $JsonPath = Join-Path $RunDir "summary.json"
    $MdPath = Join-Path $RunDir "summary.md"
    $Overall = "PASS"
    foreach ($Result in $Results) {
        if ($Result.status -ne "PASS") {
            $Overall = "FAIL"
        }
    }

    $Payload = [pscustomobject]@{
        run_id = $RunId
        status = $Overall
        results = $Results
    }
    $Payload | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -Path $JsonPath

    $Lines = @(
        "# Delivery Gate Run",
        "",
        "Run ID: $RunId",
        "",
        "Status: $Overall",
        "",
        "| Step | Status | Message |",
        "| --- | --- | --- |"
    )
    foreach ($Result in $Results) {
        $Msg = ($Result.message -replace "\|", "/")
        $Lines += "| ``$($Result.name)`` | $($Result.status) | ``$Msg`` |"
    }
    $Lines | Set-Content -Encoding UTF8 -Path $MdPath
}

Invoke-GateStep `
    -Name "a4_scheduler_vector_check" `
    -Action { python W8A12_3lane\tools\check_a4_scheduler_vectors.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\resource\A4_scheduler_vector_check\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "a4_scheduler_flow_static" `
    -Action { python W8A12_3lane\tools\check_a4_scheduler_flow_static.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\resource\A4_scheduler_flow_static\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "accel_top_flow_static" `
    -Action { python W8A12_3lane\tools\check_accel_top_flow_static.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\top\accel_top_flow_static\summary.md") `
    -ExpectedText "Status: PASS"

if (-not $SkipVivado) {
    Invoke-GateStep `
        -Name "accel_top_xsim" `
        -Action { powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_accel_top.ps1 } `
        -ExpectedFiles @("W8A12_3lane\evidence\top\accel_top_sim\summary.md") `
        -ExpectedText "Status: PASS"

    Invoke-GateStep `
        -Name "accel_top_ooc" `
        -Action { powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_accel_top_ooc.ps1 } `
        -ExpectedFiles @("W8A12_3lane\evidence\top\accel_top_ooc\utilization_ooc.rpt")

    Invoke-GateStep `
        -Name "accel_top_ooc_summary" `
        -Action { python W8A12_3lane\tools\summarize_ooc_result.py --tag accel_top --report-dir W8A12_3lane\evidence\top\accel_top_ooc } `
        -ExpectedFiles @("W8A12_3lane\evidence\top\accel_top_ooc\ooc_summary.md") `
        -ExpectedText "Status: PASS"

    Invoke-GateStep `
        -Name "a4_single_lane_xsim" `
        -Action { powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_single_lane_mac_scheduler.ps1 } `
        -ExpectedFiles @("W8A12_3lane\evidence\resource\A4_single_lane_mac_scheduler\single_lane_scheduler_sim_summary.md") `
        -ExpectedText "PASS"

    Invoke-GateStep `
        -Name "a4_3lane_xsim" `
        -Action { powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_mac_scheduler.ps1 } `
        -ExpectedFiles @("W8A12_3lane\evidence\resource\A4_3lane_mac_scheduler\a4_3lane_sim_summary.md") `
        -ExpectedText "PASS"

    Invoke-GateStep `
        -Name "a4_single_lane_ooc" `
        -Action { powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.ps1 } `
        -ExpectedFiles @("W8A12_3lane\evidence\resource\A4_single_lane_mac_scheduler_ooc\utilization_ooc.rpt")

    Invoke-GateStep `
        -Name "a4_3lane_ooc" `
        -Action { powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.ps1 } `
        -ExpectedFiles @("W8A12_3lane\evidence\resource\A4_3lane_mac_scheduler_ooc\utilization_ooc.rpt")

    Invoke-GateStep `
        -Name "a4_single_lane_ooc_summary" `
        -Action { python W8A12_3lane\tools\summarize_ooc_result.py --tag single_lane --report-dir W8A12_3lane\evidence\resource\A4_single_lane_mac_scheduler_ooc } `
        -ExpectedFiles @("W8A12_3lane\evidence\resource\A4_single_lane_mac_scheduler_ooc\ooc_summary.md") `
        -ExpectedText "Status: PASS"

    Invoke-GateStep `
        -Name "a4_3lane_ooc_summary" `
        -Action { python W8A12_3lane\tools\summarize_ooc_result.py --tag 3lane --report-dir W8A12_3lane\evidence\resource\A4_3lane_mac_scheduler_ooc } `
        -ExpectedFiles @("W8A12_3lane\evidence\resource\A4_3lane_mac_scheduler_ooc\ooc_summary.md") `
        -ExpectedText "Status: PASS"
}

if (-not $SkipX2) {
    Invoke-GateStep `
        -Name "x2_flow_static" `
        -Action { python W8A12_3lane\tools\check_x2_flow_static.py } `
        -ExpectedFiles @("W8A12_3lane\evidence\x2\flow_static\summary.md") `
        -ExpectedText "Status: PASS"

    Invoke-GateStep `
        -Name "x2_w8a12_export" `
        -Action { powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\export_x2_w8a12_to_rtl.ps1 } `
        -ExpectedFiles @(
            "rtl\generated\reds_span_x2_f48_w8a12\span_w8a12_rtl_manifest.json",
            "rtl\generated\reds_span_x2_f48_w8a12\postprocess\span_w8a12_postprocess_manifest.json"
        )

    Invoke-GateStep `
        -Name "x2_w8a12_export_check" `
        -Action { python W8A12_3lane\tools\check_x2_w8a12_export.py } `
        -ExpectedFiles @("W8A12_3lane\evidence\x2\w8a12_export\summary.md") `
        -ExpectedText "Status: PASS"

    Invoke-GateStep `
        -Name "x2_readiness" `
        -Action { python W8A12_3lane\tools\check_x2_reference_readiness.py } `
        -ExpectedFiles @("W8A12_3lane\evidence\x2\reference_readiness\readiness.md")

    Invoke-GateStep `
        -Name "x2_fixed_reference" `
        -Action { python W8A12_3lane\tools\w8a12_3lane_reference.py a3-tail-rgb --rtl-manifest rtl\generated\reds_span_x2_f48_w8a12\span_w8a12_rtl_manifest.json --postprocess-manifest rtl\generated\reds_span_x2_f48_w8a12\postprocess\span_w8a12_postprocess_manifest.json --out-dir W8A12_3lane\evidence\x2\reference } `
        -ExpectedFiles @("W8A12_3lane\evidence\x2\reference\summary.md") `
        -ExpectedText "Status: PASS"

    Invoke-GateStep `
        -Name "x2_fixed_reference_validation" `
        -Action { python W8A12_3lane\tools\check_x2_fixed_reference.py } `
        -ExpectedFiles @("W8A12_3lane\evidence\x2\reference_validation\validation.md") `
        -ExpectedText "Status: PASS"
}

Invoke-GateStep `
    -Name "board_report_flow_static" `
    -Action { python W8A12_3lane\tools\check_board_report_flow_static.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\board_reports\flow_static\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "jtag_recovery_checklist" `
    -Action { python W8A12_3lane\tools\generate_jtag_recovery_checklist.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\board_probe\jtag_recovery_checklist\summary.md") `
    -ExpectedText "Status:"

Invoke-GateStep `
    -Name "board_stagehash_flow_static" `
    -Action { python W8A12_3lane\tools\check_board_stagehash_flow_static.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\board_reports\stagehash_flow_static\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "board_validation_readiness" `
    -Action { python W8A12_3lane\tools\check_board_validation_readiness.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\board_reports\validation_readiness\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "quality_metric_completion_static" `
    -Action { python W8A12_3lane\tools\check_quality_metric_completion_static.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\quality_metric_completion\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "sim_fps_estimate" `
    -Action { python W8A12_3lane\tools\estimate_sim_fps.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\sim_fps_estimate\summary.md") `
    -ExpectedText "Status:"

Invoke-GateStep `
    -Name "contest_report_static" `
    -Action { python W8A12_3lane\tools\check_contest_submission_report_static.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\report_static\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "contest_report_pdf" `
    -Action { powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\export_contest_report_pdf.ps1 } `
    -ExpectedFiles @("W8A12_3lane\evidence\report_pdf\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "contest_report_docx" `
    -Action { powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\export_contest_report_docx.ps1 } `
    -ExpectedFiles @("W8A12_3lane\evidence\report_docx\summary.md", "W8A12_3lane\output\docx\W8A12_3lane_contest_submission_report.docx") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "submission_scope_static" `
    -Action { python W8A12_3lane\tools\check_submission_scope.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\submission_scope\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "repository_scope_manifest" `
    -Action { python W8A12_3lane\tools\collect_repository_scope_manifest.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\submission_scope\repository_scope_manifest.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "missing_plan_flow_static" `
    -Action { python W8A12_3lane\tools\check_missing_plan_flow_static.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\delivery_audit\missing_plan_flow_static\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "audit_flow_static" `
    -Action { python W8A12_3lane\tools\check_delivery_audit_flow_static.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\delivery_audit\audit_flow_static\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "missing_evidence_plan" `
    -Action { python W8A12_3lane\tools\generate_missing_evidence_plan.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\delivery_audit\missing_evidence_plan.md") `
    -AllowedExitCodes @(0, 1)

Invoke-GateStep `
    -Name "hard_gate_execution_queue" `
    -Action { python W8A12_3lane\tools\generate_hard_gate_execution_queue.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\delivery_audit\hard_gate_execution_queue.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "hard_gate_runner_static" `
    -Action { python W8A12_3lane\tools\check_hard_gate_runner_static.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\delivery_audit\hard_gate_runner_static\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "delivery_manifest" `
    -Action { python W8A12_3lane\tools\collect_delivery_manifest.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\delivery_manifest\manifest.md")

Invoke-GateStep `
    -Name "submission_manifest" `
    -Action { python W8A12_3lane\tools\collect_submission_package.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\submission_package\submission_manifest.md")

Invoke-GateStep `
    -Name "submission_archive" `
    -Action { python W8A12_3lane\tools\create_submission_archive.py --allow-incomplete } `
    -ExpectedFiles @("W8A12_3lane\evidence\submission_package\archive\summary.md") `
    -ExpectedText "Status:"

Invoke-GateStep `
    -Name "submission_manifest_flow_static" `
    -Action { python W8A12_3lane\tools\check_submission_manifest_flow_static.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\submission_package\flow_static\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "delivery_audit" `
    -Action { python W8A12_3lane\tools\audit_contest_delivery.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\delivery_audit\contest_delivery_audit.md")

Invoke-GateStep `
    -Name "submission_manifest_final" `
    -Action { python W8A12_3lane\tools\collect_submission_package.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\submission_package\submission_manifest.md")

Invoke-GateStep `
    -Name "delivery_evidence_matrix" `
    -Action { python W8A12_3lane\tools\generate_delivery_evidence_matrix.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\delivery_matrix\summary.md") `
    -ExpectedText "Status: PASS"

Invoke-GateStep `
    -Name "submission_manifest_matrix_final" `
    -Action { python W8A12_3lane\tools\collect_submission_package.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\submission_package\submission_manifest.md")

Invoke-GateStep `
    -Name "submission_archive_final" `
    -Action { python W8A12_3lane\tools\create_submission_archive.py --allow-incomplete } `
    -ExpectedFiles @("W8A12_3lane\evidence\submission_package\archive\summary.md") `
    -ExpectedText "Status:"

Invoke-GateStep `
    -Name "delivery_manifest_final" `
    -Action { python W8A12_3lane\tools\collect_delivery_manifest.py } `
    -ExpectedFiles @("W8A12_3lane\evidence\delivery_manifest\manifest.md")

Write-GateSummary

if (($Results | Where-Object { $_.status -ne "PASS" }).Count -gt 0) {
    exit 1
}
