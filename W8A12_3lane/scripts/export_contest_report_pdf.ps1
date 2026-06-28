param(
    [string]$Source = "W8A12_3lane\docs\contest_submission_report.md",
    [string]$PdfOut = "W8A12_3lane\output\pdf\W8A12_3lane_contest_submission_report.pdf",
    [string]$EvidenceOut = "W8A12_3lane\evidence\report_pdf"
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
    & $Python W8A12_3lane\tools\export_contest_report_pdf.py --source $Source --pdf-out $PdfOut --evidence-out $EvidenceOut
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
