# A4 单层 3-lane Conv OOC 综合尝试

## 状态

TIMEOUT / 未形成资源门限证据

## 命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_conv_ooc.ps1
```

## 结果

- Vivado OOC synthesis 启动成功。
- 目标 part: `xczu19eg-ffvc1760-2-i`。
- Top: `w8a12_3lane_conv_layer_ooc_top`。
- 运行约 10 分钟仍未生成 `utilization_ooc.rpt`。
- 已手动结束 Vivado 和 `parallel_synth_helper` 进程，避免后台任务悬挂。

## 判断

本次不能作为 A4 资源门限证据。它只证明当前 OOC 脚本入口可启动，但综合配置仍需收敛。

## 下一步

1. 改成更小的可综合资源基线，例如单 lane `OUT_CH=16` conv，而不是三 lane 同时展开。
2. 或为 `w8a12_3lane_conv_layer` 增加 synthesis-friendly 常量 bank 配置，避免综合器把大型常量阵列展开得过重。
3. 重新生成 `utilization_ooc.rpt` 后，再运行：

```powershell
python tools\check_vivado_zc706_resource_gate.py W8A12_3lane\evidence\resource\A4_conv_ooc\utilization_ooc.rpt --json-out W8A12_3lane\evidence\resource\A4_conv_ooc\xc7z045_resource_gate.json
```
