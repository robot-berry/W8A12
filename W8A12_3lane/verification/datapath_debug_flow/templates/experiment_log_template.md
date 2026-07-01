# 实验记录模板

## 基本信息

```text
tag:
date:
operator:
git_commit:
dirty_files:
bitstream:
ltx:
psu_init_tcl:
synthesis_directive:
acceptance_level:
mode_select:
input_vector:
reference_source:
output_dir:
pre_fix_run:
post_fix_run:
```

## 实验目标

```text
Question:
Expected boundary under test:
Previous matched boundary:
Previous mismatching boundary:
```

## 执行命令

```powershell
# 填写本次 run 使用的完整命令。
```

## 板端状态

```text
jtag_target_visible:
hw_axi_visible:
frame_done:
error:
status:
input_count:
output_count:
timeout:
```

## 边界结果

附上或复制 `boundary_hash_table.csv`。

```text
first_matching_boundary:
first_mismatching_boundary:
suspect_region:
rtl_owner:
```

## 下一步决策

```text
classification:
next_probe_boundary:
next_mode:
next_action:
```

## 修复记录

```text
fix_status: NOT_STARTED | PATCHED | REPLAY_PASS | FULL_HASH_PASS | FINAL_COMPARE_PASS | FAILED
patched_files:
patch_summary:
module_replay_result:
neighbor_interface_result:
module_ooc_result:
full_path_result:
final_compare_result:
remaining_mismatch:
```

## 备注

```text
Observed anomalies:
Files generated:
```
