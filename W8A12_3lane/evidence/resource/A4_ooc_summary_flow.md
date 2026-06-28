# A4 OOC Summary Flow

## 状态

TOOLS READY / OOC REPORTS PENDING

## 工具

```text
W8A12_3lane/tools/summarize_ooc_result.py
```

## 用法

single-lane OOC 完成后：

```powershell
python W8A12_3lane\tools\summarize_ooc_result.py --tag single_lane --report-dir W8A12_3lane\evidence\resource\A4_single_lane_mac_scheduler_ooc
```

3-lane OOC 完成后：

```powershell
python W8A12_3lane\tools\summarize_ooc_result.py --tag 3lane --report-dir W8A12_3lane\evidence\resource\A4_3lane_mac_scheduler_ooc
```

通过标准：

```text
resource_gate.pass = true
timing.pass = true
Status: PASS
```

该工具不会生成假的 OOC 结果；没有 `utilization_ooc.rpt` 时输出 `MISSING` 并返回失败。
