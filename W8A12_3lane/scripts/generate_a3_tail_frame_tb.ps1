$ErrorActionPreference = "Stop"

$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$FeatNpy = Join-Path $Repo "W8A12_3lane\evidence\reference\A3_tail_rgb\feat0.npy"
$Dump = Join-Path $Repo "W8A12_3lane\evidence\reference\A3_tail_rgb\feat0_pix_ch_dump.txt"
$OutDir = Join-Path $Repo "W8A12_3lane\evidence\reference\A3_tail_rgb\rtl_tail_frame_tb"

Push-Location $Repo
try {
    python W8A12_3lane\tools\write_feature_dump.py $FeatNpy $Dump
    python tools\generate_span_w8a12_tail_frame_tb.py --input-dump $Dump --img-w 4 --out-dir $OutDir
} finally {
    Pop-Location
}
