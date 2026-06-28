# Vivado Hardware Probe

Status: PASS

Probe directory: `board_runs/vivado_hw_target_probe_after_replug_20260628`
Target count: 1
Device count: 2

| Check | Pass | Detail |
| --- | --- | --- |
| probe_dir_exists | True | board_runs/vivado_hw_target_probe_after_replug_20260628 |
| file:vivado_log | True | board_runs/vivado_hw_target_probe_after_replug_20260628/probe_vivado_hw_targets.log |
| file:stdout_log | True | board_runs/vivado_hw_target_probe_after_replug_20260628/probe_vivado_hw_targets.stdout.log |
| file:stderr_log | True | board_runs/vivado_hw_target_probe_after_replug_20260628/probe_vivado_hw_targets.stderr.log |
| file:usb_diag | True | board_runs/vivado_hw_target_probe_after_replug_20260628/usb_jtag_devices.txt |
| pass_marker | True | VIVADO_HW_TARGET_PROBE_PASS=1 |
| target_count_positive | True | 1 |
| device_count_positive | True | 2 |
| no_no_target_error | True | No Vivado hardware target found |
| no_no_device_error | True | No Vivado hardware device found |

Required PASS marker: `VIVADO_HW_TARGET_PROBE_PASS=1`.
