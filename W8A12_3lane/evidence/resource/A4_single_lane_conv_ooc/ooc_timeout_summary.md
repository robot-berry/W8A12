# A4 单 Lane Conv OOC 综合尝试

## 状态

TIMEOUT / 未形成资源门限证据

## 命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_synth_w8a12_single_lane_conv_ooc.ps1
```

## 结果

- Vivado OOC synthesis 启动成功。
- 目标 part: `xczu19eg-ffvc1760-2-i`。
- Top: `w8a12_single_lane_conv_ooc_top`。
- 运行约 4 分钟仍未生成 `utilization_ooc.rpt`。
- 已结束 Vivado 和 `parallel_synth_helper` 进程。

## 判断

当前 `span_w8a12_conv_layer` 直接综合会展开较大的常量 bank 和乘加网络，单 lane OOC 也没有在短时间内收敛。因此 A4 不能继续依赖“直接综合 reference conv wrapper”的方式，需要拆出更小的 synthesis-friendly 计算核。

## 下一步

1. 抽象 lane 内 MAC 核：固定 `TAP_PAR` 或 `IC_PAR`，按时间复用 48 input channel x 9 taps。
2. 常量 bank 改成可推断 ROM/BRAM 的同步读接口。
3. 对 MAC 核、单 lane、3 lane wrapper 分三级 OOC 综合，逐级记录 XC7Z045 资源门限。
