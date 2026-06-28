# Accelerator Top Shell

`rtl/top/w8a12_3lane_accel_top.v` 是 A5 上板前的板端控制/status 顶层骨架。

该模块不声称已经实现完整数据通路；它的作用是把已建立的 tile pipeline 控制契约固定成一个可综合、可接 PS/寄存器层的顶层接口。

## 1. 接口定位

| 接口 | 方向 | 说明 |
| --- | --- | --- |
| `start_i` | input | 软件或寄存器层写 1 启动一帧/tile |
| `clear_i` | input | 清除 done/error，并复位 tile shell |
| `*_start_o` | output | load/conv1/spab/tail/write 阶段启动脉冲 |
| `*_done_i` | input | 外部阶段 engine 完成 |
| `*_error_i` | input | 外部阶段 engine 错误 |
| `frame_done_o` | output | 完成锁存 |
| `error_o` | output | 错误锁存 |
| `irq_o` | output | `frame_done_o | error_o` |
| `status_o` | output | 软件可读状态字 |

## 2. 状态字

```text
status_o[0]     start_q
status_o[1]     frame_done
status_o[2]     error
status_o[3]     irq
status_o[4]     busy
status_o[7:5]   phase
status_o[10:8]  block_idx
status_o[11]    read_buf
status_o[12]    write_buf
status_o[15:13] lane_valid
```

`phase` 与 `w8a12_3lane_tile_pipeline_shell` 一致：

```text
0 IDLE
1 LOAD
2 CONV1
3 SPAB
4 TAIL
5 WRITE
6 DONE
7 ERROR
```

## 3. A5 接入方式

A5 32x32 上板 smoke 可以先把外部 engine 接成最小完成模型：

```text
load_start  -> load_done
conv1_start -> conv1_done
spab_start  -> spab_done
tail_start  -> tail_done
write_start -> write_done
```

这样可先验证 PS/寄存器/IRQ/status 链路。随后逐步替换：

1. load engine 接 DDR/BRAM 输入。
2. conv1 接 A4 scheduler。
3. SPAB loop 接 6-block datapath。
4. tail 接 pixelshuffle/RGB writer。
5. write engine 接 DDR 输出。

## 4. 当前证据

静态检查：

```text
W8A12_3lane/evidence/top/accel_top_static/summary.md
W8A12_3lane/evidence/top/accel_top_flow_static/summary.md
```

第一份证据证明顶层接口、状态位和 tile shell 连接存在；第二份证据证明控制面 xsim/OOC 脚本、testbench 断言和报告生成链路已经接入。二者都不替代 board smoke、OOC timing/resource 或 bitstream。

## 5. 仿真门禁

控制面 xsim：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_accel_top.ps1
```

PowerShell 通道异常时可用 `.cmd` 包装；Vivado 返回 0 后会自动调用 `summarize_xsim_result.py --preset accel_top` 生成 `summary.md/json`：

```cmd
W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_accel_top.cmd
```

期望：

```text
PASS w8a12_3lane_accel_top spab_count=6
```

通过后生成：

```text
W8A12_3lane/evidence/top/accel_top_sim/summary.md
W8A12_3lane/evidence/top/accel_top_sim/summary.json
```

## 6. OOC 资源门禁

控制/status 顶层 OOC：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_accel_top_ooc.ps1
python W8A12_3lane\tools\summarize_ooc_result.py --tag accel_top --report-dir W8A12_3lane\evidence\top\accel_top_ooc
```

PowerShell 通道异常时可用 `.cmd` 包装；Vivado 返回 0 后会自动调用 OOC 汇总脚本：

```cmd
W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_accel_top_ooc.cmd
```

通过后生成：

```text
W8A12_3lane/evidence/top/accel_top_ooc/utilization_ooc.rpt
W8A12_3lane/evidence/top/accel_top_ooc/timing_ooc.rpt
W8A12_3lane/evidence/top/accel_top_ooc/ooc_summary.md
```
