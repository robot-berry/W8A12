param(
    [string]$Manifest = "W8A12_3lane\evidence\board_reports\validation_closure\manifest_template.json",
    [switch]$ContinueOnError,
    [switch]$DryRun,
    [string]$SummaryDir = "W8A12_3lane\evidence\board_reports\validation_closure"
)

$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$BundledPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if (Test-Path $BundledPython) {
    $Python = $BundledPython
} else {
    $Python = "python"
}

Push-Location $Repo
try {
    $Args = @(
        "W8A12_3lane\tools\finalize_board_reports_from_manifest.py",
        $Manifest,
        "--summary-dir",
        $SummaryDir
    )
    if ($ContinueOnError) { $Args += "--continue-on-error" }
    if ($DryRun) { $Args += "--dry-run" }
    & $Python @Args
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
