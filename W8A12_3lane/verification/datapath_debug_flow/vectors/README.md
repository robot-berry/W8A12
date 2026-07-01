# Vectors

本目录保存小规模验证输入向量的索引和说明。

优先准备：

```text
zero
constant_gray
ramp
impulse
true2x2_real_sample
```

每个向量建议记录：

```text
vector_manifest.json
input_format
width/height/channels
expected_input_count
expected_output_count
sha256 or crc32
```

定位阶段优先使用 `true2x2`。只有 `true2x2` 边界 PASS 后，再扩大到 `4x4`、`8x8`、`32x32`。
