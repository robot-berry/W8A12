# References

本目录保存本验证工程使用的 golden reference 摘要或链接。

建议每个 reference 子目录包含：

```text
reference_manifest.json
expected_boundary_hashes.csv
input_vector_hash.txt
source_summary.md
```

不要把大型 `.npy/.npz/.pth/.pt` 直接放进本目录；这些文件通常已被 `.gitignore` 忽略。大型原始文件请记录绝对路径、生成脚本和 SHA256。
