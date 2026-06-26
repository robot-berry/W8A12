param(
  [Parameter(Mandatory=$true)]
  [string]$RedsRoot
)

$logDir = "runs/official_span_logs"
New-Item -ItemType Directory -Force $logDir | Out-Null
$logPath = Join-Path $logDir "train_stdout.log"

$cmd = "powershell -ExecutionPolicy Bypass -File scripts/train_official_span_reds_x4.ps1 -RedsRoot `"$RedsRoot`" *> `"$logPath`""
Start-Process -FilePath "powershell" -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd -WindowStyle Hidden
Write-Host "Started official SPAN training. Log: $logPath"
