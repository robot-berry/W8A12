# A4 3-Lane MAC Scheduler OOC

## 状态

PENDING

## 运行命令

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\run_vivado_synth_w8a12_3lane_mac_scheduler_ooc.ps1
```

## 期望产物

- `utilization_ooc.rpt`
- `timing_ooc.rpt`
- `w8a12_3lane_mac_scheduler_ooc.dcp`
- XC7Z045 resource gate JSON/MD

运行前应先完成 3-lane bit-exact 仿真。
