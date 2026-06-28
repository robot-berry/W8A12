# GitHub 上传计划

目标仓库：

```text
robot-berry/W8A12
```

上传目录建议保持新主线入口：

```text
W8A12_3lane/
```

但仓库不能只包含该目录。x2/x4 量化和模型到 RTL 常量导出还依赖根目录工具链，上传范围要求见：

```text
W8A12_3lane/docs/submission_scope_policy.md
```

## 上传前必须检查

1. 运行或刷新交付审计：

```powershell
python W8A12_3lane\tools\audit_contest_delivery.py
```

2. 生成缺口计划、提交包清单、提交草案归档和交付 manifest：

```powershell
python W8A12_3lane\tools\generate_missing_evidence_plan.py
powershell -NoProfile -ExecutionPolicy Bypass -File W8A12_3lane\scripts\export_contest_report_pdf.ps1
python W8A12_3lane\tools\collect_submission_package.py
python W8A12_3lane\tools\create_submission_archive.py --allow-incomplete
python W8A12_3lane\tools\collect_delivery_manifest.py
```

3. 运行 GitHub 上传前置检查：

```powershell
python W8A12_3lane\tools\check_github_upload_preflight.py
```

该检查会阻止以下风险：

- 当前 Git remote 不是 `https://github.com/robot-berry/W8A12.git`；
- 已暂存文件包含 `W8A12_3lane/` 以外的路径；
- 缺少审计、提交 manifest、PDF 报告或草案归档摘要。

当前本地仓库保留原 `origin=https://github.com/robot-berry/feitengspan1.git`，并已新增 `w8a12=https://github.com/robot-berry/W8A12.git`。上传前必须只 stage `W8A12_3lane/` 目录，推送时使用 `w8a12` remote，避免把根目录历史脏文件推入目标仓库。

4. 生成干净上传树：

```powershell
python W8A12_3lane\tools\export_github_upload_tree.py
```

导出目录为：

```text
W8A12_3lane/output/github_upload/robot-berry_W8A12_upload_tree/
```

该目录被 `W8A12_3lane/.gitignore` 排除，用于从干净目录单独 `git init` 后上传，避免把当前 `feitengspan1` 大仓库历史推入 `robot-berry/W8A12`。

5. 检查：

```text
W8A12_3lane/evidence/delivery_audit/contest_delivery_audit.md
W8A12_3lane/evidence/delivery_audit/missing_evidence_plan.md
W8A12_3lane/evidence/report_pdf/summary.md
W8A12_3lane/output/pdf/W8A12_3lane_contest_submission_report.pdf
W8A12_3lane/evidence/delivery_matrix/summary.md
W8A12_3lane/evidence/github_upload_preflight/summary.md
W8A12_3lane/evidence/github_upload_export/summary.md
W8A12_3lane/evidence/github_upload_push/summary.md
W8A12_3lane/evidence/submission_package/submission_manifest.md
W8A12_3lane/evidence/submission_package/archive/summary.md
W8A12_3lane/evidence/delivery_manifest/manifest.md
```

## 当前允许上传的内容

可上传：

- `README.md`
- `WORKFLOW.md`
- `STATUS.md`
- `DELIVERY_INDEX.md`
- `docs/contest_submission_readme.md`
- `output/pdf/W8A12_3lane_contest_submission_report.pdf`
- `docs/`
- `rtl/`
- `sim/`
- `scripts/`
- `tools/`
- `evidence/` 下的 summary、hash、static check、audit、manifest、submission package manifest
- `evidence/report_pdf/summary.md` 和 rendered PNG 校验证据
- `evidence/delivery_matrix/summary.md` 评审证据矩阵
- `evidence/submission_package/archive/summary.md` 和 `summary.json`，用于记录提交草案 zip 的 SHA256；`.zip` 本体不纳入递归 manifest
- 根目录 `tools/` 中的 W8A12 导出工具，至少包括 `submission_scope_policy.md` 列出的 6 个脚本
- 根目录 `scripts/` 中的板端 JTAG/stage-hash 脚本，至少包括 `submission_scope_policy.md` 列出的 `run_w8a12_board_recovery_preflight.ps1`、`run_w8a12_stagehash_true2x2_acceptance.ps1`、JTAG probe、PS init、smoke、寄存器读取和 bitstream 生成脚本
- `external/SPAN/basicsr/` 中 SPAN 模型定义依赖，至少保证 `basicsr.archs.span_arch.SPAN` 可导入

暂不建议上传大文件：

- Vivado `.dcp`
- `.bit`
- `.xsa`
- 大型 `.log` / `.jou`
- 大型 `.npy`
- checkpoint `.pth/.pt`
- 自动生成的提交草案 `.zip`，除非评审平台明确要求上传单包文件

如果最终评审要求 bitstream 或 checkpoint，建议使用 Release/网盘/附件单独提交，并在 `docs/contest_submission_readme.md` 与 board report 中给出路径和 SHA256。

## 交付完成前禁止声明

如果 `contest_delivery_audit.md` 仍为 `INCOMPLETE`，则不能在 README 或提交说明中声明“赛题交付完成”。只能说明：

```text
当前为 W8A12_3lane 新主线交付包草案，A0-A3/A4 部分证据已完成，A4 sim/OOC、A5-A7 board 和 x2 fixed/board 待补齐。
```
