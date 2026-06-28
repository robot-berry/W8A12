# Vivado Probe Launcher Diagnostics

Status: NOT_READY

Current Codex process cannot reliably launch/read PowerShell/Vivado hardware probe; use root scripts/probe_vivado_hw_targets.ps1 from an external PowerShell if needed.

spawn_status: null
spawn_signal: null
spawn_error: spawnSync C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe EPERM

Next manual command from repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\probe_vivado_hw_targets.ps1 -OutputDir board_runs\vivado_hw_target_probe_w8a12_3lane
```
