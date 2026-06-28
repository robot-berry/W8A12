# MAC / DSP48 映射策略

本文档定义 `W8A12_3lane` 新主线里 MAC 单元和 Xilinx DSP 资源的使用规则。目标是在 `xczu19eg-ffvc1760-2-i` 上可以实现，同时资源评估口径保持 ZC706 / XC7Z045 或资源相当 FPGA 兼容。

## 1. 主线策略

主线不直接绑定 Vivado IP Catalog 的 MAC IP，而是使用可综合 RTL MAC：

```text
int8 activation * int12 weight -> signed product -> wide accumulator -> requant/clip
```

RTL MAC 层允许使用综合属性提示 Vivado 映射 DSP48，例如 `use_dsp = "yes"`。这样做的原因是：

- 源码可读、可仿真、可移植，便于提交赛题源代码。
- Vivado 可以在 Zynq-7000 的 DSP48E1 和 Zynq UltraScale+ 的 DSP48E2 上分别映射。
- OOC resource report 可以直接统计 LUT/FF/BRAM/DSP，并按 XC7Z045 门限验收。

## 2. 可选 Primitive 封装

如果 OOC 综合证明推断结果不稳定，才新增底层 wrapper：

```text
w8a12_dsp48_mac_wrapper.v
  -> `ifdef W8A12_USE_DSP48E1`: DSP48E1 path for XC7Z045 / ZC706-equivalent check
  -> `ifdef W8A12_USE_DSP48E2`: DSP48E2 path for xczu19eg board optimization
  -> default: portable inferred RTL MAC
```

wrapper 必须保持端口和数值语义不变。任何 primitive 优化都不能改变 A0/A1/A2/A3 的 bit-exact reference 结果。

## 3. 3-lane 资源口径

三路 output-channel 并行仍然按以下方式统计资源：

```text
lane0: output channels  0..15
lane1: output channels 16..31
lane2: output channels 32..47
```

每路 lane 读取完整 48 输入通道。DSP 数量以实际 OOC/implementation report 为准，不能用理论 MAC 数替代综合报告。

## 4. 验收标准

MAC/DSP 映射必须同时满足：

| 项目 | 通过条件 |
| --- | --- |
| 功能 | A0 single conv、A1 single block、A2 six blocks、A3 tail/RGB 均与 Python W8A12 reference bit-exact |
| A4 仿真 | single-lane scheduler 和 3-lane scheduler xsim PASS |
| A4 资源 | single-lane、3-lane、accelerator top OOC report 均低于 XC7Z045 门限 |
| 时序 | OOC/implementation timing status PASS，WNS/WHS 非负 |
| 上板 | A5/A6/A7 board report 中资源、时序、功耗、延迟、FPS、PSNR/bit-exact 证据齐全 |

当前如果只有 static/vector evidence，不能声明 MAC/DSP 映射已经通过赛题交付；必须等 Vivado xsim/OOC 和上板报告补齐后，审计才可以转为 PASS。
