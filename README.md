# Snapdragon 8 Elite KernelSU Tweaker

面向 **Snapdragon 8 Elite (SM8750)** 的 KernelSU/Magisk 模块，目标是流畅与省电平衡。

## 调优目标

- CPU
  - M 核策略频率动态限制在约 **1996~2000 MHz**
  - L 核策略频率动态限制在约 **2438 MHz**
- GPU
  - 限制在约 **900~1000 MHz**
- DDR/DDRQOS/LLCC
  - DDR: min=547000, max=2092000, boost=547000 (并递归覆盖 bus_dcvs/DDR 下所有 max_freq=2092000)
  - DDRQOS: min/max/boost=1
  - LLCC: min/max/boost=350000 (含 gold/prime 与全局 LLCC 显式节点)
- CPUSET
  - 低优先级后台：`background=0-3`，`l-background/restricted/kswapd-like=0-2`，`camera-background/storage_occupied=0-4`
  - 中优先级后台：`system-background/audio-app/scene-daemon/oiface_bg/h-background=0-5,6`
  - 高优先级交互：`top-app/foreground/foreground_window/display/camera-daemon/sf/oiface_fg/oiface_fg+=0-7`
- WALT + schedutil
  - 使用偏平衡参数，减少峰值功耗并维持响应速度

## 新增功能

- Android 版本检测：仅在 **Android 15+ (SDK>=35)** 执行调优。
- EAS 调度增强：启用 `/proc/eas_opt/eas_opt_enable=2` 与 `group_adjust_enable=1`。
- Doze 自动控制：
  - 息屏后立即尝试进入 **Light Doze**。
  - 持续 5 分钟无唤醒后尝试进入 **Deep Doze**。
- Vulkan/RenderEngine 参数与内存/LMK参数整合（通过 `resetprop`/`setprop` 尝试设置）。
- ZRAM 优化：按内存容量自动调整 zram 大小，统一使用 lz4，重建 swap 并设置高优先级。

## 日志

- 主日志路径：`/data/adb/ksu_tweaker/tune.log`


## 维护机制

- 日志自动清理：后台守护每 12 小时检查一次日志，超过 1MB 时自动裁剪，降低常驻唤醒频率。
- WALT/schedutil：重新优化迁核阈值、boost门槛和速率限制，降低抖动与无效升频。
