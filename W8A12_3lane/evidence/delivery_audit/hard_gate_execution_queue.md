# Hard Gate Execution Queue

Status: PASS

Remaining hard gate count: 4

该文件只给出剩余硬门槛的执行顺序和命令，不替代 Vivado/x2/上板 PASS 证据。

## 1. a5.board_32x32

- category: `board_x4`
- required path: `W8A12_3lane/evidence/board_reports/a5_32x32/validation.md`
- required text: `Status: PASS`
- requires external process: `True`

```powershell
python W8A12_3lane\tools\create_board_report.py --tag a5_32x32 --scale 4 --lr-width 32 --lr-height 32 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode "tile+halo crop-stitch"
python W8A12_3lane\tools\finalize_board_report_from_outputs.py W8A12_3lane\evidence\board_reports\a5_32x32\summary.json --board-output <board_output.rgb> --fixed-reference <fixed_reference.rgb> --frame-done true --error false --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --power-w <power> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing>
python W8A12_3lane\tools\validate_board_report.py W8A12_3lane\evidence\board_reports\a5_32x32\summary.json --json-out W8A12_3lane\evidence\board_reports\a5_32x32\validation.json --md-out W8A12_3lane\evidence\board_reports\a5_32x32\validation.md
```

## 2. a6.board_64x64

- category: `board_x4`
- required path: `W8A12_3lane/evidence/board_reports/a6_64x64/validation.md`
- required text: `Status: PASS`
- requires external process: `True`

```powershell
python W8A12_3lane\tools\create_board_report.py --tag a6_64x64 --scale 4 --lr-width 64 --lr-height 64 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode "tile+halo crop-stitch"
python W8A12_3lane\tools\finalize_board_report_from_outputs.py W8A12_3lane\evidence\board_reports\a6_64x64\summary.json --board-output <board_output.rgb> --fixed-reference <fixed_reference.rgb> --frame-done true --error false --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --power-w <power> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing>
python W8A12_3lane\tools\validate_board_report.py W8A12_3lane\evidence\board_reports\a6_64x64\summary.json --json-out W8A12_3lane\evidence\board_reports\a6_64x64\validation.json --md-out W8A12_3lane\evidence\board_reports\a6_64x64\validation.md
```

## 3. a7.board_720p_x4

- category: `board_x4`
- required path: `W8A12_3lane/evidence/board_reports/a7_720p_x4/validation.md`
- required text: `Status: PASS`
- requires external process: `True`

```powershell
python W8A12_3lane\tools\create_board_report.py --tag a7_720p_x4 --scale 4 --lr-width 320 --lr-height 180 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode "tile+halo crop-stitch"
python W8A12_3lane\tools\finalize_board_report_from_outputs.py W8A12_3lane\evidence\board_reports\a7_720p_x4\summary.json --board-output <board_output.rgb> --fixed-reference <fixed_reference.rgb> --frame-done true --error false --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --power-w <power> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing>
python W8A12_3lane\tools\validate_board_report.py W8A12_3lane\evidence\board_reports\a7_720p_x4\summary.json --json-out W8A12_3lane\evidence\board_reports\a7_720p_x4\validation.json --md-out W8A12_3lane\evidence\board_reports\a7_720p_x4\validation.md
```

## 4. x2.board

- category: `x2_export_reference_board`
- required path: `W8A12_3lane/evidence/board_reports/x2_720p/validation.md`
- required text: `Status: PASS`
- requires external process: `True`

```powershell
python W8A12_3lane\tools\create_board_report.py --tag x2_720p --scale 2 --lr-width 640 --lr-height 360 --tile-width 32 --tile-height 32 --halo 21 --target-fps 15 --input-source SD --tiling-mode "tile+halo crop-stitch"
python W8A12_3lane\tools\finalize_board_report_from_outputs.py W8A12_3lane\evidence\board_reports\x2_720p\summary.json --board-output <board_output.rgb> --fixed-reference <fixed_reference.rgb> --frame-done true --error false --lut-used <lut> --ff-used <ff> --bram-tile-used <bram_tile> --dsp-used <dsp> --wns-ns <wns> --whs-ns <whs> --clock-mhz <clock> --latency-ms <latency> --fps <fps_ge_15> --power-w <power> --bitstream <bitstream> --utilization-report <utilization> --timing-report <timing>
python W8A12_3lane\tools\validate_board_report.py W8A12_3lane\evidence\board_reports\x2_720p\summary.json --json-out W8A12_3lane\evidence\board_reports\x2_720p\validation.json --md-out W8A12_3lane\evidence\board_reports\x2_720p\validation.md
```
