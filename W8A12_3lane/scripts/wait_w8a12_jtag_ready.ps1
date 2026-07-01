param(
  [int]$MaxSeconds = 300,
  [int]$IntervalSeconds = 10,
  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

$workspaceRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$repoRoot = Resolve-Path (Join-Path $workspaceRoot "..")
$checker = Join-Path $repoRoot "scripts\check_w8a12_jtag_stack.ps1"

if (-not (Test-Path $checker)) {
  throw "JTAG stack checker not found: $checker"
}

if (-not $OutputRoot) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path $workspaceRoot "verification\datapath_debug_flow\runs\jtag_stack_wait_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$deadline = (Get-Date).AddSeconds($MaxSeconds)
$attempt = 0
$lastSummaryMd = ""
$lastStatus = "NOT_RUN"

while ((Get-Date) -le $deadline) {
  $attempt += 1
  $tryDir = Join-Path $OutputRoot ("try_{0:D2}" -f $attempt)
  New-Item -ItemType Directory -Force -Path $tryDir | Out-Null

  Write-Host "W8A12_JTAG_READY_WAIT_ATTEMPT=$attempt"
  $rawOutput = & $checker -OutputDir $tryDir *>&1
  $output = @($rawOutput | ForEach-Object { $_.ToString() })
  $output | ForEach-Object { Write-Host $_ }

  $statusLine = $output | Where-Object { $_ -match "^W8A12_JTAG_STACK_STATUS=" } | Select-Object -Last 1
  if ($statusLine) {
    $lastStatus = ($statusLine -replace "^W8A12_JTAG_STACK_STATUS=", "").Trim()
  }

  $summaryLine = $output | Where-Object { $_ -match "^W8A12_JTAG_STACK_SUMMARY_MD=" } | Select-Object -Last 1
  if ($summaryLine) {
    $lastSummaryMd = ($summaryLine -replace "^W8A12_JTAG_STACK_SUMMARY_MD=", "").Trim()
  }

  if ($lastStatus -eq "READY") {
    Write-Host "W8A12_JTAG_READY_WAIT_STATUS=READY"
    Write-Host "W8A12_JTAG_READY_WAIT_OUTPUT_ROOT=$OutputRoot"
    if ($lastSummaryMd) {
      Write-Host "W8A12_JTAG_READY_WAIT_LAST_SUMMARY_MD=$lastSummaryMd"
    }
    exit 0
  }

  if ((Get-Date).AddSeconds($IntervalSeconds) -gt $deadline) {
    break
  }

  Start-Sleep -Seconds $IntervalSeconds
}

Write-Host "W8A12_JTAG_READY_WAIT_STATUS=TIMEOUT"
Write-Host "W8A12_JTAG_READY_WAIT_LAST_STATUS=$lastStatus"
Write-Host "W8A12_JTAG_READY_WAIT_OUTPUT_ROOT=$OutputRoot"
if ($lastSummaryMd) {
  Write-Host "W8A12_JTAG_READY_WAIT_LAST_SUMMARY_MD=$lastSummaryMd"
}
exit 2
