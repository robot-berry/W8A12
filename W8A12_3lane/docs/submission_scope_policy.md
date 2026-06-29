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

## 4. 板端综合所需根目录 RTL

JTAG true2x2/stage-hash bitstream 的 Vivado Tcl 明确引用根目录 RTL。赛题交付要求包含硬件加速器源代码，因此上传仓库不能只包含脚本，还必须包含最小可综合 RTL 依赖：

```text
rtl/board/
rtl/span/
rtl/generated/reds_span_x4_f48_w8a12/
```

其中 `rtl/generated/reds_span_x4_f48_w8a12/` 包含 x4、48 channels、W8A12 对应的量化参数、postprocess LUT 和 block-group 常量。该目录是源码/参数交付物，不等同于 Vivado 生成物；`.bit/.xsa/.dcp/.jou/.log/.wdb` 等构建输出仍不允许进入上传范围。

最低必须能找到以下文件：

```text
rtl/board/sr_jtag_w8a12_tile_writer_endpoint.v
rtl/board/sr_tile_halo_fetch_w8a12_front_tail_writer_shell.v
rtl/board/sr_w8a12_block_group_spab_c1c2c3_attention_buffered_tile_engine.v
rtl/span/span_w8a12_tail_streamed_rgb.v
rtl/span/span_w8a12_parallel_conv_vector_streamed_weights.v
rtl/generated/reds_span_x4_f48_w8a12/span_w8a12_layers.vh
rtl/generated/reds_span_x4_f48_w8a12/postprocess/span_w8a12_postprocess.vh
rtl/generated/reds_span_x4_f48_w8a12/block_group/span_w8a12_block_group_mem.vh
```

## 5. 上传前检查

上传前至少确认：

```powershell
python W8A12_3lane\tools\check_x2_flow_static.py
python W8A12_3lane\tools\check_board_stagehash_flow_static.py
python W8A12_3lane\tools\collect_submission_package.py
python W8A12_3lane\tools\audit_contest_delivery.py
```

`check_x2_flow_static.py` 会检查根目录导出工具是否存在；`collect_submission_package.py` 会列出 `W8A12_3lane` 新主线文件；`audit_contest_delivery.py` 决定当前交付是否满足赛题门槛。

## 6. 不可替代项

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
