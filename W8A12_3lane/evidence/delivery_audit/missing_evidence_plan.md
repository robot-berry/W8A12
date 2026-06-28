# Missing Evidence Plan

Missing count: 4

该文件把当前交付审计中未通过的项目映射到下一步命令。命令执行成功后仍需重新运行 `audit_contest_delivery.py`。

## a5.board_32x32

- required path: `W8A12_3lane/evidence/board_reports/a5_32x32/validation.md`
- required text: `Status: PASS`
- note: Skeleton report is not enough; replace placeholders in update_board_report.py command with real board data/files before validation can PASS.

```powershell
python W8A12_3lane\tools\create_board_report.py --tag a5_32x32 --scale 4 --lr-width 32 --lr-height 32 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode "tile+halo crop-stitch"
python W8A12_3lane\tools\update_board_report.py W8A12_3lane\evidence\board_reports\a5_32x32\summary.json --status PASS --frame-done true --error false --mismatch 0 --bit-exact true --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --resource-status PASS --timing-status PASS --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --target-fps 15 --power-w <power> --psnr-db <psnr_ge_28> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing> --fixed-reference <fixed_reference> --board-output <board_output>
python W8A12_3lane\tools\validate_board_report.py W8A12_3lane\evidence\board_reports\a5_32x32\summary.json --json-out W8A12_3lane\evidence\board_reports\a5_32x32\validation.json --md-out W8A12_3lane\evidence\board_reports\a5_32x32\validation.md
```

## a6.board_64x64

- required path: `W8A12_3lane/evidence/board_reports/a6_64x64/validation.md`
- required text: `Status: PASS`
- note: Depends on A5 passing.

```powershell
python W8A12_3lane\tools\create_board_report.py --tag a6_64x64 --scale 4 --lr-width 64 --lr-height 64 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode "tile+halo crop-stitch"
python W8A12_3lane\tools\update_board_report.py W8A12_3lane\evidence\board_reports\a6_64x64\summary.json --status PASS --frame-done true --error false --mismatch 0 --bit-exact true --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --resource-status PASS --timing-status PASS --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --target-fps 15 --power-w <power> --psnr-db <psnr_ge_28> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing> --fixed-reference <fixed_reference> --board-output <board_output>
python W8A12_3lane\tools\validate_board_report.py W8A12_3lane\evidence\board_reports\a6_64x64\summary.json --json-out W8A12_3lane\evidence\board_reports\a6_64x64\validation.json --md-out W8A12_3lane\evidence\board_reports\a6_64x64\validation.md
```

## a7.board_720p_x4

- required path: `W8A12_3lane/evidence/board_reports/a7_720p_x4/validation.md`
- required text: `Status: PASS`
- note: Depends on A6 and full-frame/tile integration.

```powershell
python W8A12_3lane\tools\create_board_report.py --tag a7_720p_x4 --scale 4 --lr-width 320 --lr-height 180 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode "tile+halo crop-stitch"
python W8A12_3lane\tools\update_board_report.py W8A12_3lane\evidence\board_reports\a7_720p_x4\summary.json --status PASS --frame-done true --error false --mismatch 0 --bit-exact true --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --resource-status PASS --timing-status PASS --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --target-fps 15 --power-w <power> --psnr-db <psnr_ge_28> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing> --fixed-reference <fixed_reference> --board-output <board_output>
python W8A12_3lane\tools\validate_board_report.py W8A12_3lane\evidence\board_reports\a7_720p_x4\summary.json --json-out W8A12_3lane\evidence\board_reports\a7_720p_x4\validation.json --md-out W8A12_3lane\evidence\board_reports\a7_720p_x4\validation.md
```

## x2.board

- required path: `W8A12_3lane/evidence/board_reports/x2_720p/validation.md`
- required text: `Status: PASS`
- note: Depends on x2 fixed reference and board integration; replace placeholders with real board data/files.

```powershell
python W8A12_3lane\tools\create_board_report.py --tag x2_720p --scale 2 --lr-width 640 --lr-height 360 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode "tile+halo crop-stitch"
python W8A12_3lane\tools\update_board_report.py W8A12_3lane\evidence\board_reports\x2_720p\summary.json --status PASS --frame-done true --error false --mismatch 0 --bit-exact true --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --resource-status PASS --timing-status PASS --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --target-fps 15 --power-w <power> --psnr-db <psnr_ge_30> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing> --fixed-reference <fixed_reference> --board-output <board_output>
python W8A12_3lane\tools\validate_board_report.py W8A12_3lane\evidence\board_reports\x2_720p\summary.json --json-out W8A12_3lane\evidence\board_reports\x2_720p\validation.json --md-out W8A12_3lane\evidence\board_reports\x2_720p\validation.md
```
