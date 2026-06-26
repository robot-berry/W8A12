param(
  [int]$IntervalSeconds = 30
)

while ($true) {
  python train/visualize_official_span.py `
    --log runs/official_span_logs_x2/train_stdout.log `
    --output runs/official_span_x2/dashboard.html `
    --title "Official SPAN x2 Training" `
    --total-iter 300000 | Out-Null
  Start-Sleep -Seconds $IntervalSeconds
}
