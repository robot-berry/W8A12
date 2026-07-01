# 边界 Hash 与 Debug Bank 规划

本文件定义当前 mismatch 工作流使用的边界 hash。原则是：每个边界只在 `valid && ready` 成立时更新，读回后按固定顺序比较，第一处 mismatch 决定下一轮 RTL owner。

## 当前比较顺序

```text
src_feat0_hash
src_b1_hash
src_b6_act1_hash
tail_b1_hash
tail_b6_act1_hash
tail_rgb_q_hash
writeback_hash
```

## true2x2 参考值

```text
src_feat0_hash     = 0xF7F21881
src_b1_hash        = 0x16EDE581
src_b6_act1_hash   = 0xC7A096FB
tail_b1_hash       = 0x16EDE1C2
tail_b6_act1_hash  = 0xC7A092B8
tail_rgb_q_hash    = 0xB712A61B
writeback_hash     = 0x61D3EA1D
```

`src_*` 使用 indexed hash，因此与对应 `tail_*` 的 unindexed hash 不完全相同。

## Bank 0

兼容旧 stage-hash 读法：

| 寄存器槽 | 字段 |
| --- | --- |
| `REG_INPUT_FLAGS` | `tail_b1_hash` |
| `REG_INPUT_PIXEL` | `tail_b6_act1_hash` |
| `REG_OUTPUT_FLAGS` | `tail_rgb_q_hash` |
| `REG_DEBUG_WRITEBACK_HASH` | `writeback_hash` |
| `REG_DEBUG_WRITEBACK_RANGE` | `writeback_range` |
| `REG_DEBUG_WRITEBACK_FIRST` | `writeback_first` |
| `REG_DEBUG_WRITEBACK_LAST` | `writeback_last` |

## Bank 1

保留旧 dbg2 兼容字段：

| 寄存器槽 | 字段 | 备注 |
| --- | --- | --- |
| `REG_INPUT_FLAGS` | `bank1_tail_feat0_hash` | 当前是诊断/范围字段，不参与边界判定 |
| `REG_INPUT_PIXEL` | `src_feat0_hash` | 旧路径可读 |
| `REG_OUTPUT_FLAGS` | `src_b1_hash` | 旧路径可读 |
| `REG_DEBUG_WRITEBACK_HASH` | `tail_b1_hash` | 镜像 |
| `REG_DEBUG_WRITEBACK_RANGE` | `tail_b6_act1_hash` | 镜像 |
| `REG_DEBUG_WRITEBACK_FIRST` | `tail_rgb_q_hash` | 镜像 |
| `REG_DEBUG_WRITEBACK_LAST` | `writeback_hash` | 镜像 |

## Bank 2

`DEBUG_EXPORT_LEVEL>=3` 时用于 SPAB block1 deep hash。当前 source-b6 工作流不依赖 bank2。

## Bank 3

当前 source-b6 主定位 bank：

| 寄存器槽 | 字段 |
| --- | --- |
| `REG_INPUT_FLAGS` | `src_feat0_hash` |
| `REG_INPUT_PIXEL` | `src_block6_hash` |
| `REG_OUTPUT_FLAGS` | `src_b1_hash` |
| `REG_DEBUG_WRITEBACK_HASH` | `src_b6_act1_hash` |
| `REG_DEBUG_WRITEBACK_RANGE` | `tail_b1_hash` |
| `REG_DEBUG_WRITEBACK_FIRST` | `tail_b6_act1_hash` |
| `REG_DEBUG_WRITEBACK_LAST` | `tail_rgb_q_hash` |

## 当前优先级

```text
P0: src_b6_act1_hash
P0: tail_b6_act1_hash
P0: tail_b1_hash
P0: tail_rgb_q_hash
P1: src_block6_hash
P1: writeback range/first/last
P2: SPAB block6 deep hash 或 raw dump
```

`bank1_tail_feat0_hash` 只作为诊断显示，不能作为 P0 边界。
