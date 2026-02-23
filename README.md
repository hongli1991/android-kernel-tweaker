# Snapdragon 8 Elite KernelSU Tweaker

一个专门面向 **Snapdragon 8 Elite (SM8750)** 的 KernelSU/Magisk 模块，目标是简洁、可维护、开机自动生效。

## 调优目标

- CPU
  - M 核策略频率动态限制在约 **1996~2000 MHz**
  - L 核策略频率动态限制在约 **2438 MHz**
- GPU
  - 限制在约 **900~1000 MHz**
- DDR/DDRQOS/LLCC
  - DDR: max=209200, min=547000, boost=547000
  - DDRQOS: max/min/boost=1
  - LLCC: max=350000, min=350000, boost=350000
- CPUSET
  - background: 0-3
  - system-background: 2-4
  - top-app/foreground/foreground_window/display/sf: 0-5
  - 其余分组按常见 Android 调度组做保守分配（偏省电并兼顾流畅）
- WALT + schedutil
  - 启用并设置一组面向高通平台的平衡参数（流畅度与持续功耗折中）

## 文件结构

- `service.sh`：开机完成后执行主调优脚本
- `tune.sh`：核心调优逻辑
- `scripts/lib.sh`：通用读写/频点选择/SOC 检测函数

## 兼容与安全

- 仅在检测到 Snapdragon 8 Elite 相关标识（如 `8 Elite` / `SM8750`）时生效。
- 所有写入都通过“节点存在才写”的方式执行，避免在不同内核上硬写崩溃。

## 日志

- 日志路径：`/data/adb/ksu_tweaker/tune.log`
