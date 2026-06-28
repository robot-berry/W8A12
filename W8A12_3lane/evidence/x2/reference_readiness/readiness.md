# x2 W8A12 Fixed Reference Readiness

状态：READY

| 项目 | 状态 | 路径 |
| --- | --- | --- |
| `checkpoint_300000` | OK | `runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_300000.pth` |
| `checkpoint_latest` | OK | `runs/official_span/official_SPAN_REDS_x2_f48/models/net_g_latest.pth` |
| `train_log` | OK | `runs/official_span/official_SPAN_REDS_x2_f48/train_official_SPAN_REDS_x2_f48_20260524_161741.log` |
| `fp32_manifest` | OK | `rtl/generated/official_span_x2/official_span_manifest.json` |
| `w8a12_rtl_manifest` | OK | `rtl/generated/reds_span_x2_f48_w8a12/span_w8a12_rtl_manifest.json` |
| `w8a12_postprocess_manifest` | OK | `rtl/generated/reds_span_x2_f48_w8a12/postprocess/span_w8a12_postprocess_manifest.json` |
| `w8a12_quant_plan` | OK | `runs/reds_span_quant_plan/reds_span_x2_f48_w8a12/span_w8a12_quant_plan.json` |

该检查只确认 x2 fixed reference 的输入材料是否齐全；不能替代 `W8A12_3lane/evidence/x2/reference/summary.md`。