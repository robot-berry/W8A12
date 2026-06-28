# A4 Scheduler 验收流程

## 目标

A4 的目标是把已经通过的 `TAP_PAR=8` MAC core 接到 lane/scheduler 层，并逐级证明：

1. single-output scheduler 对齐 A0 的一个输出通道。
2. single-lane scheduler 对齐 A0 的 lane0 16 个输出通道。
3. 3-lane scheduler 对齐 A0 的完整 48 个输出通道。
4. 完成 XC7Z045 资源门限和 timing 报告。

## 已有证据

| 层级 | 状态 | 证据 |
| --- | --- | --- |
| MAC core | PASS | `evidence/resource/A4_lane_mac_core_ooc/mac_core_ooc_summary.md` |
| single-output scheduler | PASS | `evidence/resource/A4_single_out_mac_scheduler/single_out_scheduler_sim_summary.md` |
| single-lane scheduler | RTL/TB ready | `evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_status.md` |
| 3-lane scheduler | STATIC/VECTOR/FLOW CHECK PASS / sim pending | `evidence/resource/A4_scheduler_vector_check/summary.md`, `evidence/resource/A4_scheduler_flow_static/summary.md` |

## 执行顺序

先跑 single-lane：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_single_lane_mac_scheduler.ps1
```

期望日志：

```text
PASS w8a12_single_lane_mac_scheduler pixels=16 lane_ch=16
```

通过后脚本会生成：

```text
W8A12_3lane/evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_sim_summary.md
W8A12_3lane/evidence/resource/A4_single_lane_mac_scheduler/single_lane_scheduler_sim_summary.json
W8A12_3lane/evidence/resource/A4_single_lane_mac_scheduler/vivado_single_lane_mac_scheduler.log
```

再跑 3-lane：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_mac_scheduler.ps1
```

期望日志：

```text
PASS w8a12_3lane_mac_scheduler pixels=16 channels=48
```

通过后脚本会生成：

```text
W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.md
W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler/a4_3lane_sim_summary.json
W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler/vivado_3lane_mac_scheduler.log
```

若当前终端调用 Vivado 失败，可以使用 `.cmd` 包装：

```cmd
W8A12_3lane\scripts\run_vivado_sim_w8a12_single_lane_mac_scheduler.cmd
W8A12_3lane\scripts\run_vivado_sim_w8a12_3lane_mac_scheduler.cmd
```

`.cmd` 包装在 Vivado 返回 0 后会自动调用：

```powershell
python W8A12_3lane\tools\summarize_xsim_result.py --preset a4_single_lane
python W8A12_3lane\tools\summarize_xsim_result.py --preset a4_3lane
```

如果已经手动跑过 Tcl，只要 `build/.../simulate.log` 中有 PASS 行，也可以单独运行上述命令补齐审计 summary。

仿真通过后跑 OOC synthesis：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.ps1
```

如果当前 PowerShell 通道异常，可以使用 `.cmd` 包装。Vivado 返回 0 后会自动调用 OOC 汇总脚本：

```cmd
W8A12_3lane\scripts\run_vivado_synth_w8a12_single_lane_mac_scheduler_ooc.cmd
W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.cmd
```

OOC 输出目录：

```text
W8A12_3lane/evidence/resource/A4_single_lane_mac_scheduler_ooc/
W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler_ooc/
```

综合脚本必须至少落盘：

```text
utilization_ooc.rpt
timing_ooc.rpt
vivado_*_ooc.log
```

OOC 完成后生成汇总和门限判定：

```powershell
python W8A12_3lane\tools\summarize_ooc_result.py --tag single_lane --report-dir W8A12_3lane\evidence\resource\A4_single_lane_mac_scheduler_ooc
python W8A12_3lane\tools\summarize_ooc_result.py --tag 3lane --report-dir W8A12_3lane\evidence\resource\A4_3lane_mac_scheduler_ooc
```

`summarize_ooc_result.py` 已内置 XC7Z045/ZC706 门限和 Vivado hierarchical utilization 解析，不依赖旧线 `tools/` 目录。当前解析器自检见：

```text
W8A12_3lane/evidence/resource/A4_ooc_parser_selfcheck/summary.md
```

汇总产物：

```text
ooc_summary.md
ooc_summary.json
```

当 Vivado 暂时不可用时，可先运行静态检查：

```powershell
python W8A12_3lane\tools\check_a4_3lane_scheduler_static.py
python W8A12_3lane\tools\check_a4_scheduler_flow_static.py
```

以及 A4 scheduler 向量一致性检查：

```powershell
python W8A12_3lane\tools\check_a4_scheduler_vectors.py
```

当前已生成：

```text
W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler/a4_3lane_static_check.md
W8A12_3lane/evidence/resource/A4_3lane_mac_scheduler/a4_3lane_static_check.json
W8A12_3lane/evidence/resource/A4_scheduler_flow_static/summary.md
W8A12_3lane/evidence/resource/A4_scheduler_flow_static/summary.json
W8A12_3lane/evidence/resource/A4_scheduler_vector_check/summary.md
W8A12_3lane/evidence/resource/A4_scheduler_vector_check/summary.json
```

注意：静态检查只确认 lane 绑定、TB 比对范围、OOC 源文件列表、OOC wrapper 和 A0 fixture 一致；向量检查只确认 A0 fixture 下 3-lane 计算/拼接与 full48 reference 0 mismatch。两者都不替代 Vivado/xsim。

## 通过标准

single-lane 通过标准：

- 使用 A0 `input_feature.txt` 作为输入。
- 输出 lane0 channels 0..15。
- 每个 pixel/channel 与 A0 `full48_output.txt` 对应通道 bit-exact。

3-lane 通过标准：

- 使用 A0 `input_feature.txt` 作为输入。
- lane0/1/2 分别输出 channels 0..15、16..31、32..47。
- 拼接后的 48ch 输出与 A0 `full48_output.txt` 全通道 bit-exact。

资源通过标准：

- 器件评估按 XC7Z045/ZC706 等价门限。
- LUT <= 218600。
- FF <= 437200。
- BRAM Tile <= 545。
- DSP <= 900。
- 不允许使用 URAM 作为通过依据。
- `ooc_summary.md` 必须显示 `Status: PASS`。

## 失败回退

如果 single-lane 不通过：

1. 回到 single-output scheduler，先固定一个 `OUT_INDEX` 复现。
2. 检查 16 个子 scheduler 的 `s_valid/s_ready` 与 `m_valid/m_ready` 是否同步。
3. 若只有部分通道错误，优先检查对应 lane mem 的权重、bias、requant、shift 索引。

如果 3-lane 不通过：

1. 保留 single-lane PASS 证据。
2. 分别单独实例化 lane0/lane1/lane2。
3. 若各 lane 单独通过但拼接失败，检查 `feat_o` packed bit slice。
4. 若某 lane 单独失败，检查该 lane 的 A0 mem 文件绑定。

如果 OOC 超资源：

1. 保留 3-lane bit-exact sim PASS。
2. 将 16-output fully parallel lane 改为 8-output 或 4-output time-mux lane。
3. 重新记录 DSP/LUT/BRAM 与吞吐下降比例。
