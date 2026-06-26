param(
  [string]$Checkpoint = "runs/official_span/official_SPAN_REDS_x4_f48/models/net_g_295000.pth",
  [ValidateSet(2, 4)]
  [int]$Scale = 4,
  [int]$Channels = 48,
  [double]$BestPsnr = 28.3118,
  [string]$Tag = "reds_span_x4_f48_best295k",
  [string]$OutputDir = "rtl/generated",
  [string]$DatasetRoot = "G:\REDS",
  [string]$SpanRoot = "external/SPAN",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Get-DirectoryByteCount {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    return 0
  }
  $sum = 0
  Get-ChildItem -Path $Path -Recurse -File | ForEach-Object { $sum += $_.Length }
  return $sum
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  $checkpointExists = Test-Path $Checkpoint
  $datasetExists = Test-Path $DatasetRoot
  $spanRootExists = Test-Path $SpanRoot
  $exportDir = Join-Path $OutputDir $Tag
  $manifestPath = Join-Path $exportDir "official_span_manifest.json"
  $summaryDir = "runs/reds_span_hardware_handoff"
  $summaryJson = Join-Path $summaryDir ("handoff_{0}.json" -f $Tag)
  $summaryMd = Join-Path $summaryDir ("handoff_{0}.md" -f $Tag)

  $plannedArgs = @(
    "python",
    "train\export_official_span_to_rtl.py",
    "--checkpoint", $Checkpoint,
    "--scale", [string]$Scale,
    "--channels", [string]$Channels,
    "--best-psnr", [string]$BestPsnr,
    "--tag", $Tag,
    "--output-dir", $OutputDir,
    "--source-label", "REDS-trained SPAN via external/SPAN architecture",
    "--dataset-name", "REDS competition dataset",
    "--dataset-root", $DatasetRoot,
    "--span-root", $SpanRoot
  )
  $planned = $plannedArgs -join " "

  if ($DryRun) {
    Write-Host "DRY_RUN=1"
    Write-Host "CHECKPOINT_EXISTS=$checkpointExists"
    Write-Host "DATASET_EXISTS=$datasetExists"
    Write-Host "SPAN_ROOT_EXISTS=$spanRootExists"
    Write-Host "PLAN_EXPORT=$planned"
    return
  }

  if (-not $checkpointExists) {
    throw "Checkpoint not found: $Checkpoint"
  }
  if (-not $datasetExists) {
    throw "Dataset root not found: $DatasetRoot"
  }
  if (-not $spanRootExists) {
    throw "SPAN root not found: $SpanRoot"
  }

  $env:KMP_DUPLICATE_LIB_OK = "TRUE"
  $env:PYTHONPATH = (Resolve-Path $SpanRoot).Path

  python train/export_official_span_to_rtl.py `
    --checkpoint $Checkpoint `
    --scale $Scale `
    --channels $Channels `
    --best-psnr $BestPsnr `
    --tag $Tag `
    --output-dir $OutputDir `
    --source-label "REDS-trained SPAN via external/SPAN architecture" `
    --dataset-name "REDS competition dataset" `
    --dataset-root $DatasetRoot `
    --span-root $SpanRoot
  if ($LASTEXITCODE -ne 0) {
    throw "REDS SPAN export failed with exit code $LASTEXITCODE"
  }
  if (-not (Test-Path $manifestPath)) {
    throw "Manifest was not generated: $manifestPath"
  }

  $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
  $weightFiles = Get-ChildItem -Path (Join-Path $exportDir "weights") -File -Filter *.mem
  $artifactBytes = Get-DirectoryByteCount -Path $exportDir

  New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
  $summary = [ordered]@{
    status = "PASS"
    target = "REDS-trained SPAN X$Scale F$Channels"
    checkpoint = $Checkpoint
    checkpoint_full_path = (Resolve-Path $Checkpoint).Path
    dataset_root = (Resolve-Path $DatasetRoot).Path
    scale = $Scale
    channels = $Channels
    best_psnr = $BestPsnr
    tag = $Tag
    export_dir = $exportDir
    manifest = $manifestPath
    manifest_source = $manifest.source
    training_dataset = $manifest.training_dataset
    weight_count = $manifest.weights.Count
    weight_files = $weightFiles.Count
    artifact_bytes = $artifactBytes
  }
  $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryJson -Encoding UTF8

  $lines = @(
    "# REDS-trained SPAN hardware handoff",
    "",
    "Status: PASS",
    "",
    "This handoff uses the mature SPAN checkpoint trained on the REDS competition dataset under $($summary.dataset_root). The external/SPAN code is used as the architecture/loader; the selected weights are local REDS-trained weights, not upstream pretrained weights.",
    "",
    "## Selected checkpoint",
    "",
    "- checkpoint: $Checkpoint",
    "- scale/channels: X$Scale / F$Channels",
    "- best validation PSNR: $BestPsnr dB",
    "- export tag: $Tag",
    "",
    "## Export artifacts",
    "",
    "- export directory: $exportDir",
    "- manifest: $manifestPath",
    "- weight tensors in manifest: $($summary.weight_count)",
    "- weight files: $($summary.weight_files)",
    "- artifact bytes: $($summary.artifact_bytes)",
    "",
    "## Next hardware gate",
    "",
    "1. Rebuild the full SPAN X4 bitstream with these generated headers/weights.",
    "2. Run JTAG board acceptance with the same input image.",
    "3. Generate a comparison PNG for every test run: input, software PyTorch SPAN, fixed-point/RTL reference, board output, and amplified diff.",
    "",
    "Suggested command after the bitstream is rebuilt:",
    "",
    '```powershell',
    "powershell -ExecutionPolicy Bypass -File scripts\run_full_span_hardware_acceptance.ps1 -Scale 4 -ImgW 32 -Checkpoint runs\official_span\official_SPAN_REDS_x4_f48\models\net_g_295000.pth -ExportTag reds_span_x4_f48_best295k -InputPng external\SPAN\test_scripts\data\baboon.png",
    '```',
    ""
  )
  Set-Content -Path $summaryMd -Value $lines -Encoding UTF8

  Write-Host "REDS_SPAN_HANDOFF_PASS=1"
  Write-Host "REDS_SPAN_HANDOFF_MANIFEST=$manifestPath"
  Write-Host "REDS_SPAN_HANDOFF_SUMMARY=$summaryMd"
  Write-Host "REDS_SPAN_HANDOFF_WEIGHT_COUNT=$($summary.weight_count)"
}
finally {
  Pop-Location
}
