# A4 Scheduler Vector Check

Status: PASS

| Item | Value |
| --- | --- |
| `single_lane0_hash` | `0x32746552` |
| `lane1_hash` | `0xF9404568` |
| `lane2_hash` | `0x17220394` |
| `stitched_hash` | `0x8020E858` |
| `expected_full48_hash` | `0x8020E858` |
| `mismatches` | `0` |

说明：该检查复现 RTL testbench 的 A0 输入窗口、3-lane 通道拼接和 `span_w8a12_requant` 公式，用于提前验证 A4 scheduler 的映射规则。
它不能替代 Vivado xsim 和 OOC 综合，最终交付仍要求对应仿真/资源报告 PASS。
