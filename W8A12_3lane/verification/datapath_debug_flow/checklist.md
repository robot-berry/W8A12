# 数据通路调试检查清单

每次实验前后按本清单检查，避免把环境问题、旧 bitstream 或旧输出误判成 datapath mismatch。

## Run 前检查

```text
[ ] 记录 git commit 和 dirty files。
[ ] 记录 bitstream 路径和构建时间。
[ ] 记录 synthesis directive。
[ ] 记录 input vector tag 和 SHA256/hash。
[ ] 记录 expected reference 文件或 hash 来源。
[ ] 如果上一次 run 留下 error/busy high，先 power-cycle 或 reset board。
[ ] 运行 JTAG/AXI preflight。
[ ] 清空所有 debug counter 和 hash register。
```

## Run 中检查

```text
[ ] Program bitstream。
[ ] 必要时运行 PSU init。
[ ] 确认 JTAG-to-AXI core 可见。
[ ] 写入 mode_select。
[ ] 写入 input/vector 配置。
[ ] assert start。
[ ] 带 timeout 轮询 busy/frame_done/error。
[ ] 读取 status、counter、debug bank。
[ ] 保存原始 console log。
```

## Run 后检查

```text
[ ] 确认 frame_done = 1。
[ ] 确认 error = 0。
[ ] 确认 input_count 符合预期。
[ ] 确认 output_count 符合预期。
[ ] 填写 boundary_hash_table.csv。
[ ] 标记 first matching boundary。
[ ] 标记 first mismatching boundary。
[ ] 决定 next probe boundary。
[ ] 复制 logs 到 runs/<tag>/。
```

## RTL 修改前检查

```text
[ ] 第一处 mismatch boundary 已在相同 input 和 bitstream 下复现。
[ ] suspect region 已映射到 rtl_target_map.md。
[ ] 已从 fast_sim_synth_acceptance.md 选择 acceptance level。
[ ] 已选择 replay 或 bypass 策略。
[ ] 只选择一个 RTL owner 作为 patch 目标。
[ ] 已记录 pre-fix run tag。
```

## RTL 修改后检查

```text
[ ] 已记录 patched files。
[ ] module replay test PASS，或失败原因已说明。
[ ] neighbor interface simulation PASS，或失败原因已说明。
[ ] module OOC synthesis PASS，或有明确 waive 原因。
[ ] 已重跑 true2x2 full boundary hash。
[ ] 如果 full hash PASS，已重跑 final board/reference compare。
[ ] 已记录 post-fix run tag。
[ ] 如果未修复，已更新 remaining mismatch boundary。
```

## 停止条件

出现下面情况时，停止继续看图像输出，优先修基础链路：

```text
JTAG target not visible
AXI-Lite magic/scratch fails
frame_done = 0
error != 0
input_count unexpected
output_count unexpected
status stuck busy
hash count = 0 at a boundary that should receive data
```

## 有效结论格式

每轮定位实验结论必须写成：

```text
Matched through: <boundary_name>
First mismatch: <boundary_name>
Suspect region: <module/interface/path>
Next action: <specific next probe or replay test>
```

修复闭环结论必须写成：

```text
RTL owner: <file/module>
Patch: <one-line summary>
Replay: PASS/FAIL
Full hash: PASS/FAIL
Final compare: PASS/FAIL
Mismatch status: FIXED/OPEN
```

不要写成：

```text
output mismatch, need further debug
```

这种结论不会缩小搜索范围。
