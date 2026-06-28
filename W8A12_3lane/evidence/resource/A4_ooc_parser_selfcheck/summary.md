# A4 OOC Parser Selfcheck

Status: PASS

| Metric | Expected | Actual | Result |
| --- | ---: | ---: | --- |
| lut | 51 | 51 | PASS |
| ff | 49 | 49 | PASS |
| bram | 0 | 0 | PASS |
| dsp | 8 | 8 | PASS |
| uram | 0 | 0 | PASS |

该自检使用已有 MAC core Vivado hierarchical utilization 报告，确认 `summarize_ooc_result.py` 的自包含解析逻辑覆盖当前报告格式。
