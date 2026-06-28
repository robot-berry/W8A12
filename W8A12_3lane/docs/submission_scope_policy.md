# 提交范围和外部工具依赖

`W8A12_3lane` 是新主线工程入口，但赛题交付不是只提交一个孤立目录。模型训练、量化、W8A12 导出和 fixed reference 仍依赖根目录工具链。上传到 `robot-berry/W8A12` 时，必须把这些依赖一并纳入仓库。

## 1. 必须随仓库提交的根目录工具

```text
tools/calibrate_span_activation_scales.py
tools/export_span_w8a12_quant_plan.py
tools/export_span_quant_plan_to_rtl.py
tools/export_span_w8a12_postprocess_to_rtl.py
tools/check_span_w8a12_rtl_export.py
tools/run_span_ptq_reference.py
```

其中 `calibrate_span_activation_scales.py` 和 `export_span_w8a12_quant_plan.py` 依赖 `run_span_ptq_reference.py`。`run_span_ptq_reference.py` 依赖 SPAN 模型定义：

```text
basicsr.archs.span_arch.SPAN
```

当前工程中的源码路径为：

```text
external/SPAN/basicsr/archs/span_arch.py
```

因此上传仓库必须同时包含 `external/SPAN/basicsr/` 中对应模型源码，或在交付文档中给出可复现的安装/检出方式。

## 2. W8A12_3lane 内部工具

`W8A12_3lane/tools/` 负责新主线的验收和证据生成：

```text
check_x2_w8a12_export.py
check_x2_fixed_reference.py
check_x2_reference_readiness.py
find_x2_assets.py
w8a12_3lane_reference.py
audit_contest_delivery.py
collect_submission_package.py
collect_delivery_manifest.py
```

这些工具生成赛题交付 evidence，但不能替代根目录导出工具。

## 3. 板端 JTAG/stage-hash 根目录脚本

stage-hash true2x2 上板验收入口位于：

```text
W8A12_3lane/scripts/run_w8a12_board_recovery_preflight.ps1
W8A12_3lane/scripts/run_w8a12_stagehash_true2x2_acceptance.ps1
```

该入口是交付包内的薄包装，实际执行仍依赖仓库根目录下的板端脚本。上传到 `robot-berry/W8A12` 时必须一并包含：

```text
scripts/run_w8a12_board_recovery_preflight.ps1
scripts/run_w8a12_stagehash_true2x2_acceptance.ps1
scripts/probe_vivado_hw_targets.ps1
scripts/probe_vivado_hw_targets.tcl
scripts/check_usb_jtag_devices.ps1
scripts/cleanup_vivado_processes.ps1
scripts/run_xsct_psu_init_only.ps1
scripts/run_xsct_psu_init_only.tcl
scripts/run_jtag_w8a12_tile_writer_smoke.ps1
scripts/jtag_rgb_transfer.tcl
scripts/compare_jtag_w8a12_span_output.ps1
scripts/run_read_jtag_w8a12_tile_writer_regs.ps1
scripts/read_jtag_w8a12_tile_writer_regs.tcl
scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.ps1
scripts/run_vivado_bitstream_jtag_w8a12_tile_writer.tcl
scripts/create_vivado_jtag_w8a12_tile_writer_bd_project.tcl
```

这些脚本不替代最终 board validation，但它们是恢复 JTAG target 后继续定位 mismatch 的最小自动化入口。

## 4. 上传前检查

上传前至少确认：

```powershell
python W8A12_3lane\tools\check_x2_flow_static.py
python W8A12_3lane\tools\check_board_stagehash_flow_static.py
python W8A12_3lane\tools\collect_submission_package.py
python W8A12_3lane\tools\audit_contest_delivery.py
```

`check_x2_flow_static.py` 会检查根目录导出工具是否存在；`collect_submission_package.py` 会列出 `W8A12_3lane` 新主线文件；`audit_contest_delivery.py` 决定当前交付是否满足赛题门槛。

## 5. 不可替代项

以下证据必须由实际流程生成，不能用提交范围说明替代：

```text
evidence/x2/w8a12_export/summary.md
evidence/x2/reference/summary.md
evidence/x2/reference_validation/validation.md
evidence/top/accel_top_sim/summary.md
evidence/top/accel_top_ooc/ooc_summary.md
evidence/resource/A4_*_ooc/ooc_summary.md
evidence/board_reports/*/validation.md
```

也就是说，本文件只说明“交付包应该包含什么源码和工具”，不改变当前审计中 x2、Vivado、上板硬门槛的状态。
