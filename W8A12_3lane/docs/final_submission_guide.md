# W8A12_3lane 最终提交指南

日期：2026-07-03

本文档作为评审入口页，说明 `W8A12_3lane/` 在“正确性仿真通过 + 可生成 bitstream + 提供 PPA/资源时序报告，真实插板运行不作为硬门槛”的赛题口径下如何提交、如何复现、哪些指标可以声明、哪些仍属于后续工程验证。

## 1. 推荐提交入口

| 用途 | 文件 |
| --- | --- |
| 中文技术报告 PDF | `output/pdf/W8A12_3lane_contest_submission_report.pdf` |
| 中文技术报告 Word | `output/docx/W8A12_3lane_contest_submission_report.docx` |
| 完整 Word 导出版 | `output/docx/W8A12_3lane_contest_submission_report_complete_20260701.docx` |
| 交付索引 | `DELIVERY_INDEX.md` |
| 赛题提交说明 | `docs/contest_submission_readme.md` |
| 赛题要求追踪矩阵 | `docs/contest_requirement_traceability.md` |
| 赛题口径门禁 | `evidence/contest_scope_readiness/summary.md` |
| 赛题口径提交包摘要 | `evidence/contest_scope_package/summary.md` |
| 严格上板归档摘要 | `evidence/submission_package/archive/summary.md` |

评审时建议先阅读 PDF/Word 报告，再查看 `evidence/contest_scope_readiness/summary.md` 和 `evidence/contest_scope_package/summary.md`。如果评审要求真实板端 32x32/64x64/720p 输出，则必须以严格上板归档和 `evidence/delivery_audit/contest_delivery_audit.md` 为准。

## 2. 当前可声明结论

| 项目 | 当前声明 |
| --- | --- |
| x4 画质目标 | SPAN x4/F48 FP32：REDS val 全量 PSNR RGB `28.3118 dB`，达到 `>=28 dB` |
| x2 画质目标 | SPAN x2/F48 FP32：REDS val 全量 PSNR RGB `34.4297 dB`，达到 `>=30 dB` |
| 传统插值对比 | x4 相对 bicubic 提升 `+2.0169 dB`；x2 相对 bicubic 提升 `+3.5652 dB` |
| W8A12 量化 | 权重 INT8、激活 12-bit；x2 W8A12 export/fixed reference/validation PASS |
| RTL 分层验证 | A0/A1/A2/A3/A4/top shell 证据齐全，分层 reference/hash/xsim/OOC 已收录 |
| x4 FPS | 720p x4 scheduler/performance-model：`24x72` 为 17.501 FPS @250MHz、888 DSP；`24x64` 为 15.070 FPS、792 DSP |
| x2 FPS 复核 | 720p x2 direct `xvlog/xelab/xsim` 复跑与 Vivado batch summary 一致；`24x72` 为 4.483 FPS @250MHz、888 DSP，仍不声明 x2 720p20 |
| x2 FPS | 降目标 720p x2 scheduler/performance-model：`24x72` 为 4.483 FPS @250MHz、888 DSP |
| PPA | A4 3-lane scheduler OOC 为 LUT 123182、FF 256222、DSP 672、WNS 1.188ns，低于 XC7Z045/ZC706 门限 |
| BRAM | `evidence/resource/bram_accounting/summary.md` 已补充：x4 W8A12/F48 模型常量下限 119.32 BRAM36，32x32 tile buffer 下限 142.23 BRAM36；true2x2/JTAG-W8A12 为 311/545，A5 32x32 attempt 为 415.5/545 |
| bitstream/PPA gate | true2x2/JTAG-W8A12 bitstream implementation 为 `PASS_WITH_SCOPE`，资源为 LUT 39799、FF 116685、BRAM 311、DSP 128、WNS 12.580ns |
| mismatch 最新定位 | dbg6 已导出 C1/C2 detail bank，RTL raw compare 仍 `0/192` mismatch；dbg6 bitstream 尚未生成，下一步是上板读取 bank6 |
| A5 最新上板定位 | 32x32 attempt 已通过 software reference、program 和 DDR input verify，资源门限 PASS；但 PL 超时，`frame_done=0/output_read_pixels=0`，不作为 validation PASS |

## 3. 不可声明内容

以下内容目前不能写成已完成：

机器可检索口径：`physical_board_720p_output = NOT_CLAIMED`，`x2_720p20_scheduler_fps = NOT_CLAIMED`。

- 真实板端 720p 输出已完成。
- x4/x2 板端 PSNR、FPS 或功耗已实测闭合。
- A5 32x32 board validation 已通过。当前只有失败定位证据，没有 `validation.md Status: PASS`。
- 720p packed 2-D 完整像素计算 RTL bit-exact 闭合。
- x2 720p20 已在 900-DSP 门限内达成。当前 x2 720p20 scheduler 证据结论为 FAIL。
- 严格 board-validation audit 已 PASS。当前严格审计仍为 `INCOMPLETE`。

## 4. 严格上板后续缺口

严格上板口径仍缺以下 4 项真实板端 validation：

```text
evidence/board_reports/a5_32x32/validation.md
evidence/board_reports/a6_64x64/validation.md
evidence/board_reports/a7_720p_x4/validation.md
evidence/board_reports/x2_720p/validation.md
```

这些缺口不影响“无真实插板硬门槛”的赛题报告/PPA 提交口径，但如果评审要求真实上板输出，则必须补齐后重新生成报告和提交包。

## 5. 本地复现命令

在 `G:/UESTC/feitengspan1` 下运行：

```powershell
python W8A12_3lane\tools\check_contest_submission_report_static.py
python W8A12_3lane\tools\calc_bram_accounting.py
python W8A12_3lane\tools\check_contest_scope_readiness.py
python W8A12_3lane\tools\collect_submission_package.py
python W8A12_3lane\tools\create_contest_scope_package.py
python W8A12_3lane\tools\create_submission_archive.py --allow-incomplete
python W8A12_3lane\tools\check_github_upload_preflight.py
```

说明：

- `collect_submission_package.py` 在严格上板缺口未补齐时会返回非零，但会刷新 `submission_manifest`；这是预期行为。
- `create_contest_scope_package.py` 应输出 `CONTEST_SCOPE_PACKAGE_STATUS=PASS_WITH_SCOPE`。
- `create_submission_archive.py --allow-incomplete` 应输出 `SUBMISSION_ARCHIVE_STATUS=INCOMPLETE`，用于保留严格上板风险说明。
- 本地生成的 `.zip` 归档被 `.gitignore` 排除；GitHub 上传树保留摘要、SHA256 和复现脚本，不提交 zip 本体。

## 6. GitHub 上传口径

当前上传分支为：

```text
robot-berry/W8A12:codex/w8a12-3lane-delivery-draft
```

上传前必须保证：

```powershell
python W8A12_3lane\tools\check_github_upload_preflight.py
```

输出为：

```text
GITHUB_UPLOAD_PREFLIGHT_STATUS=PASS
```

提交时只 stage `W8A12_3lane/` 范围内文件，根目录其他上板调试文件不属于本赛题提交包。
