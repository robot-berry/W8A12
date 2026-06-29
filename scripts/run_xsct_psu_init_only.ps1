param(
  [string]$XsctBat = "D:\software\2025.2\Vitis\bin\xsct.bat",
  [string]$PsuInitTcl,
  [string]$OutputDir = "board_runs\psu_init_only\latest"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Resolve-WorkspacePath {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return "" }
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
}

if ([string]::IsNullOrWhiteSpace($PsuInitTcl)) {
  throw "PsuInitTcl is required"
}

Push-Location $root
try {
  if (-not (Test-Path $XsctBat)) { throw "XSCT executable not found: $XsctBat" }
  $psuInitAbs = (Resolve-Path -LiteralPath $PsuInitTcl).Path
  $outDirAbs = Resolve-WorkspacePath $OutputDir
  New-Item -ItemType Directory -Path $outDirAbs -Force | Out-Null

  $log = Join-Path $outDirAbs "run_xsct_psu_init_only.log"
  $summaryJson = Join-Path $outDirAbs "psu_init_only_summary.json"
  $summaryMd = Join-Path $outDirAbs "psu_init_only_summary.md"

  Write-Host "PSU_INIT_ONLY_OUTPUT_DIR=$outDirAbs"
  Write-Host "PSU_INIT_ONLY_PSU_INIT_TCL=$psuInitAbs"
  Write-Host "PSU_INIT_ONLY_LOG=$log"

  $oldPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = "Continue"
    & $XsctBat scripts\run_xsct_psu_init_only.tcl $psuInitAbs *>&1 | Tee-Object -FilePath $log
    $xsctExit = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $oldPreference
  }

  $logText = if (Test-Path $log) { Get-Content -Path $log -Raw } else { "" }
  $pass = [bool]($logText -match "PSU_INIT_ONLY_PASS=1")
  $fail = ""
  $m = [regex]::Match($logText, "PSU_INIT_ONLY_FAIL=(.+)")
  if ($m.Success) { $fail = $m.Groups[1].Value.Trim() }

  $summary = [ordered]@{
    status = $(if ($pass -and $xsctExit -eq 0) { "PASS" } else { "FAIL" })
    xsct_exit = $xsctExit
    psu_init_tcl = $psuInitAbs
    log = $log
    failure = $fail
  }
  $summary | ConvertTo-Json -Depth 4 | Set-Content -Path $summaryJson -Encoding UTF8

  $lines = @(
    "# PSU Init Only Summary",
    "",
    "Status: $($summary.status)",
    "",
    "| Item | Value |",
    "| --- | --- |",
    "| XSCT exit | $($summary.xsct_exit) |",
    "| psu_init.tcl | `$($summary.psu_init_tcl)` |",
    "| failure | `$($summary.failure)` |",
    "| log | `$($summary.log)` |"
  )
  Set-Content -Path $summaryMd -Value $lines -Encoding UTF8

  Write-Host "PSU_INIT_ONLY_SUMMARY_JSON=$summaryJson"
  Write-Host "PSU_INIT_ONLY_SUMMARY_MD=$summaryMd"
  Write-Host "PSU_INIT_ONLY_STATUS=$($summary.status)"
  if ($summary.status -ne "PASS") {
    throw "PSU init only failed"
  }
} finally {
  Pop-Location
}
