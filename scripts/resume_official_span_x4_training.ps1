$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  $env:KMP_DUPLICATE_LIB_OK = "TRUE"
  $spanRoot = Join-Path $root "external\SPAN"
  if (-not (Test-Path $spanRoot)) {
    throw "Missing external\SPAN. Run scripts/setup_external_span.ps1 first."
  }
  $env:PYTHONPATH = "$spanRoot;$env:PYTHONPATH"

  $stateDir = "runs/official_span/official_SPAN_REDS_x4_f48/training_states"
  $latestState = Get-ChildItem $stateDir -Filter "*.state" |
    Sort-Object { [int]($_.BaseName) } -Descending |
    Select-Object -First 1

  if (-not $latestState) {
    throw "No training state found in $stateDir"
  }

  $logDir = "runs/official_span_logs"
  New-Item -ItemType Directory -Force $logDir | Out-Null
  $logPath = Join-Path $logDir "resume_stdout.log"
  $resumePath = $latestState.FullName.Replace("\", "/")

  Write-Host "Resume official SPAN x4 from $resumePath"

  $cmd = "cd external/SPAN; python basicsr/train.py -opt options/train/SPAN/train_SPAN_REDS_x4.yml --launcher none --force_yml path:resume_state=$resumePath *> `"../../$logPath`""
  Start-Process -FilePath "powershell" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd -WindowStyle Hidden
  Write-Host "Started resume process. Log: $logPath"
} finally {
  Pop-Location
}
