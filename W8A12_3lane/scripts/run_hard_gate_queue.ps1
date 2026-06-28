$ErrorActionPreference = "Stop"

param(
    [string]$Queue = "W8A12_3lane\evidence\delivery_audit\hard_gate_execution_queue.json",
    [string]$RunId = "",
    [string]$StartAt = "",
    [string]$OnlyCategory = "",
    [switch]$ContinueOnError,
    [switch]$DryRun
)

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if ($RunId -eq "") {
    $RunId = Get-Date -Format "yyyyMMdd_HHmmss"
}

$QueuePath = Join-Path $Repo $Queue
if (-not (Test-Path $QueuePath)) {
    throw "queue not found: $Queue"
}

$RunDir = Join-Path $Repo "W8A12_3lane\evidence\hard_gate_runs\$RunId"
New-Item -ItemType Directory -Force -Path $RunDir | Out-Null

$QueueData = Get-Content -Raw -Encoding UTF8 $QueuePath | ConvertFrom-Json
$Steps = @($QueueData.queue)

if ($OnlyCategory -ne "") {
    $Steps = @($Steps | Where-Object { $_.category -eq $OnlyCategory })
}

if ($StartAt -ne "") {
    $Seen = $false
    $Filtered = @()
    foreach ($Step in $Steps) {
        if ($Step.name -eq $StartAt -or [string]$Step.order -eq $StartAt) {
            $Seen = $true
        }
        if ($Seen) {
            $Filtered += $Step
        }
    }
    if (-not $Seen) {
        throw "StartAt did not match any queued step: $StartAt"
    }
    $Steps = $Filtered
}

$Results = @()

function Write-RunSummary {
    $JsonPath = Join-Path $RunDir "summary.json"
    $MdPath = Join-Path $RunDir "summary.md"
    $Overall = "PASS"
    foreach ($Result in $Results) {
        if ($Result.status -ne "PASS" -and $Result.status -ne "SKIP") {
            $Overall = "FAIL"
        }
    }

    $Payload = [pscustomobject]@{
        run_id = $RunId
        queue = $Queue
        status = $Overall
        dry_run = [bool]$DryRun
        results = $Results
    }
    $Payload | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 -Path $JsonPath

    $Lines = @(
        "# Hard Gate Queue Run",
        "",
        "Run ID: $RunId",
        "",
        "Status: $Overall",
        "",
        "Dry run: $([bool]$DryRun)",
        "",
        "| Step | Category | Status | Message |",
        "| --- | --- | --- | --- |"
    )
    foreach ($Result in $Results) {
        $Msg = ($Result.message -replace "\|", "/")
        $Lines += "| `$($Result.name)` | `$($Result.category)` | $($Result.status) | `$Msg` |"
    }
    $Lines | Set-Content -Encoding UTF8 -Path $MdPath
}

foreach ($Step in $Steps) {
    $StepDir = Join-Path $RunDir ("{0:D2}_{1}" -f [int]$Step.order, ($Step.name -replace "[^A-Za-z0-9_.-]", "_"))
    New-Item -ItemType Directory -Force -Path $StepDir | Out-Null
    $Stdout = Join-Path $StepDir "stdout.txt"
    $Stderr = Join-Path $StepDir "stderr.txt"
    $CmdFile = Join-Path $StepDir "commands.txt"
    @($Step.commands) | Set-Content -Encoding UTF8 -Path $CmdFile

    $Status = "PASS"
    $Message = ""

    if ($DryRun) {
        $Status = "SKIP"
        $Message = "dry run"
    } else {
        try {
            Push-Location $Repo
            try {
                foreach ($Command in @($Step.commands)) {
                    $global:LASTEXITCODE = 0
                    powershell -NoProfile -ExecutionPolicy Bypass -Command $Command *> $Stdout
                    if ($global:LASTEXITCODE -ne 0) {
                        throw "command exited with code ${global:LASTEXITCODE}: $Command"
                    }
                }
            } finally {
                Pop-Location
            }

            $Required = Join-Path $Repo $Step.required_path
            if (-not (Test-Path $Required)) {
                throw "missing required evidence: $($Step.required_path)"
            }
            if ($null -ne $Step.required_text -and $Step.required_text -ne "") {
                $Text = Get-Content -Raw -Encoding UTF8 $Required
                if ($Text -notmatch [regex]::Escape([string]$Step.required_text)) {
                    throw "required text not found in $($Step.required_path): $($Step.required_text)"
                }
            }
        } catch {
            $Status = "FAIL"
            $Message = $_.Exception.Message
            Set-Content -Encoding UTF8 -Path $Stderr -Value $Message
            if (-not $ContinueOnError) {
                $Results += [pscustomobject]@{
                    order = $Step.order
                    name = $Step.name
                    category = $Step.category
                    status = $Status
                    message = $Message
                }
                Write-RunSummary
                throw
            }
        }
    }

    $Results += [pscustomobject]@{
        order = $Step.order
        name = $Step.name
        category = $Step.category
        status = $Status
        message = $Message
    }
}

Write-RunSummary

if (($Results | Where-Object { $_.status -eq "FAIL" }).Count -gt 0) {
    exit 1
}
