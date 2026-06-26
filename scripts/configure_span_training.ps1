param(
  [Parameter(Mandatory=$true)]
  [string]$RedsRoot,
  [string]$RepoRoot = "",
  [int]$X4BatchSize = 16,
  [int]$X2BatchSize = 4,
  [int]$NumWorkers = 4
)

$ErrorActionPreference = "Stop"
if ($RepoRoot -eq "") {
  $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$repo = (Resolve-Path $RepoRoot).Path.Replace("\", "/")
$reds = (Resolve-Path $RedsRoot).Path.Replace("\", "/")
$optionDir = Join-Path $RepoRoot "external\SPAN\options\train\SPAN"
New-Item -ItemType Directory -Force -Path $optionDir | Out-Null

function Write-Option {
  param(
    [string]$Template,
    [string]$OutFile,
    [string]$Scale,
    [string]$BatchSize,
    [string]$CropBorder
  )

  $text = Get-Content -Raw -Path $Template
  $text = $text -replace "G:/REDS", $reds
  $text = $text -replace "G:/UESTC/feitengspan1", $repo
  $text = $text -replace "batch_size_per_gpu: \d+", "batch_size_per_gpu: $BatchSize"
  $text = $text -replace "num_worker_per_gpu: \d+", "num_worker_per_gpu: $NumWorkers"
  $text = $text -replace "crop_border: \d+", "crop_border: $CropBorder"
  Set-Content -Path $OutFile -Value $text -Encoding UTF8
  Write-Host "WROTE_OPTION_$Scale=$OutFile"
}

python scripts/create_reds_meta_info.py --root (Join-Path $RedsRoot "train_sharp") --output configs/meta_info_REDS_train_GT.txt
python scripts/create_reds_meta_info.py --root (Join-Path $RedsRoot "val_sharp") --output configs/meta_info_REDS_val_GT.txt

Write-Option `
  -Template "configs\span_options\train_SPAN_REDS_x4.template.yml" `
  -OutFile (Join-Path $optionDir "train_SPAN_REDS_x4.yml") `
  -Scale "X4" `
  -BatchSize $X4BatchSize `
  -CropBorder 4

Write-Option `
  -Template "configs\span_options\train_SPAN_REDS_x2.template.yml" `
  -OutFile (Join-Path $optionDir "train_SPAN_REDS_x2.yml") `
  -Scale "X2" `
  -BatchSize $X2BatchSize `
  -CropBorder 2

Write-Host "CONFIGURE_SPAN_TRAINING_OK"
