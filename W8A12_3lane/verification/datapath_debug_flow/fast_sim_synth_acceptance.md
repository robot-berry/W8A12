# 快速仿真和综合验收流程

本文定义一个快速有效的仿真/综合验收方法，用于减少反复全量综合、实现和上板时间。

目标：

```text
用最低成本的 gate 回答当前问题
模块 replay 和 OOC 门禁通过前，不构建 bitstream
不要把最终 board image compare 当作第一个调试信号
```

## 验收等级

每次 RTL 修改都必须从低成本 gate 开始，逐级推进。

| Level | 名称 | 目的 | 期望成本 | 必要产物 | 通过条件 |
| --- | --- | --- | --- | --- | --- |
| L0 | 静态范围门禁 | 确认改动范围和 RTL owner 正确 | 秒级 | `run_manifest.json` | `rtl_owner`、`patched_files`、`expected_boundary` 已填写 |
| L1 | 模块 replay 仿真 | 验证可疑模块的数学和握手是否修好 | 秒级到分钟级 | module replay log/hash table | replay boundary hash 与 reference 一致 |
| L2 | 邻接接口仿真 | 验证被修模块和上下游接口没有重复/漏样本 | 分钟级 | boundary hash table | 两侧 `count/hash/first/last` 一致 |
| L3 | 模块 OOC 综合 | 验证修改后模块可综合，资源/时序没有明显退化 | 分钟级 | utilization/timing summary | synthesis PASS，若有时序报告则 WNS/WHS 非负 |
| L4 | true2x2 全路径 hash | 验证完整数据通路第一失败边界已消失 | 中等 | `boundary_hash_table.csv` | true2x2 必要边界 hash 全部一致 |
| L5 | 最终输出 compare | 最终确认当前 mismatch 已修复 | 慢 | final compare report | mismatch = 0，`frame_done=1`，`error=0` |

## 晋级规则

只有当前 level PASS，才进入下一 level：

```text
L0 -> L1 -> L2 -> L3 -> L4 -> L5
```

跳级必须写入 run log。允许跳级的情况只有：

```text
纯文档或模板修改
已知 board-only wiring 修改
已知 script-only register read 修改
```

不允许跳级：

```text
datapath RTL 修改
weight/mem/requant 文件修改
valid-ready/handshake 修改
bank/address/scheduler 修改
tail/pixelshuffle/writer 修改
```

## 快环：L0 到 L2

用于高频迭代。

输入：

```text
first_failing_boundary
rtl_owner
golden vector
expected boundary hashes
```

执行：

```text
1. 跑最小模块 replay 仿真。
2. 默认只检查 count/hash/first/last。
3. replay hash 失败后才打开 waveform 或 raw dump。
4. 每轮最多新增 1 到 3 个 probe。
```

通过标准：

```text
module replay hash matches
upstream boundary count matches
downstream boundary count matches
no unexpected stall or zero-count boundary
```

失败处理：

```text
不综合
不构建 bitstream
修 RTL owner 或继续细化 probe
```

## 中环：L3

用于确认 RTL 修改不会在综合层面失效。

执行策略：

```text
优先 module OOC，不优先 full top synthesis
尽量复用已有脚本
正确性 bring-up 阶段保持 top/BD 不变
除 PPA-only 实验外保持 SynthDirective=Default
```

通过标准：

```text
synthesis completes
resource delta is explainable
timing is not obviously broken
generated reports are saved into runs/<tag>/
```

失败处理：

```text
修复被修改的 RTL owner
不要进入 bitstream 阶段
```

## 关于 post-synth full netlist sim

2026-06-30 已尝试 `true2x2` full top post-synthesis functional xsim：

```text
行为级 raw compare PASS
post-synth TCL 参数透传问题已修复
短路径 dbg0 网表仿真能进入 xsim
但 full netlist simulation 长时间没有跑到边界输出
```

因此当前快速主路径不把完整 post-synth netlist sim 作为 L3 必选项。优先级调整为：

```text
首选：模块 OOC synthesis / 小模块 post-synth sim
次选：当前源码低侵入 debug bitstream + true2x2 board boundary hash
专项调查：完整 full top post-synth netlist sim
```

如果必须使用 full post-synth sim，必须先缩短对象：

```text
减少 debug export level
缩小被测 top
降低 MaxCycles 或增加早期边界输出
使用短路径 BuildRoot
```

## 慢环：L4 到 L5

用于确认完整路径和最终输出。

L4 只看边界 hash：

```text
true2x2 input
full path enabled
debug bank reads all relevant boundary hashes
compare boundary_hash_table.csv against reference
```

L5 才看最终输出：

```text
board output raw/rgb
fixed reference raw/rgb
byte mismatch
PSNR/preview only as secondary evidence
```

通过标准：

```text
L4: 第一失败边界消失，并且所有必要边界 hash match
L5: final mismatch = 0
```

失败处理：

```text
If L4 fails:
  更新 first_failing_boundary，返回 L1，针对新的 RTL owner 继续修。

If L4 passes but L5 fails:
  聚焦 writer/readback/RGB packing，不再优先怀疑 compute module。
```

## Debug Superset Bitstream 策略

为了减少上板和实现次数，优先维护一个 debug superset bitstream：

```text
mode_select:
  MODE_REG
  MODE_LOOPBACK
  MODE_FRONTEND_ONLY
  MODE_REPLAY_BLOCK1_C1
  MODE_REPLAY_BLOCK1_C2
  MODE_REPLAY_BLOCK1_ATT
  MODE_REPLAY_TAIL
  MODE_FULL_WITH_HASH

debug_bank:
  0 tail/writeback
  1 source/b1 input
  2 block1 C1/C2/C3/attention
  3 writer/readback
```

原则：

```text
提前加入常用 probe bank
通过 debug_bank 选择观测点，而不是每新增一个 hash 就重建 bitstream
只有必要边界不可观测时才重建 bitstream
```

## 时间预算目标

这些不是硬性数字，但用于决定是否需要缩小 scope：

| Level | 目标时间 | 超时处理 |
| --- | --- | --- |
| L0 | < 1 min | 精简 run manifest 或模板 |
| L1 | < 5 min | 缩小 vector 或模块范围 |
| L2 | < 10 min | 缩小邻接接口范围 |
| L3 | < 20 min | 拆分更小 OOC target |
| L4 | bitstream 已存在时 < 15 min | 自动化 board 脚本并加 timeout |
| L5 | bitstream 已存在时 < 15 min | 先比对更小输出 |

## 必须记录的 run 字段

每次验收 run 必须记录：

```text
acceptance_level
question
rtl_owner
patched_files
input_vector
reference_source
commands
result
next_level_or_return_level
```

推荐结论格式：

```text
Level: L1 module replay
RTL owner: Block1 C1
Question: Does C1 match with golden b1_input?
Result: PASS
Next: L2 neighbor interface simulation
```

失败 run：

```text
Level: L1 module replay
RTL owner: Block1 C1
Question: Does C1 match with golden b1_input?
Result: FAIL at c1_acc_raw_hash
Return: patch C1 MAC/tap/weight path, stay at L1
```

## 当前 mismatch 的退出条件

当前 mismatch 只有在以下条件全部满足时才算修复：

```text
L1 replay PASS for the patched RTL owner
L2 neighbor interface PASS
L3 OOC PASS or explicitly waived with reason
L4 true2x2 full boundary hash PASS
L5 final output compare PASS
```

任一 level 失败时，工作流返回能解释该失败的最低成本 level。
