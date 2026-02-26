#!/system/bin/sh

MODDIR="${0%/*}"
[ -n "$MODDIR" ] || MODDIR="."
if [ ! -d "$MODDIR" ]; then
  if [ -d /data/adb/modules/sd8e_tweaker ]; then
    MODDIR=/data/adb/modules/sd8e_tweaker
  elif [ -d /data/adb/modules_update/sd8e_tweaker ]; then
    MODDIR=/data/adb/modules_update/sd8e_tweaker
  elif [ -d /data/adb/ksu/modules/sd8e_tweaker ]; then
    MODDIR=/data/adb/ksu/modules/sd8e_tweaker
  else
    MODDIR=.
  fi
fi

LOG_DIR="/data/adb/ksu_tweaker"
LOG_FILE="$LOG_DIR/tune.log"
mkdir -p "$LOG_DIR" 2>/dev/null

log() {
  printf '%s %s\n' "$(date '+%F %T' 2>/dev/null)" "$*" >>"$LOG_FILE"
}

write_if_exists() {
  [ -e "$1" ] || return 0
  printf '%s\n' "$2" >"$1" 2>/dev/null && log "set $1=$2"
}

read_value() {
  [ -r "$1" ] || return 1
  IFS= read -r _v <"$1" 2>/dev/null || return 1
  printf '%s' "$_v"
}

set_prop_safe() {
  k="$1"
  v="$2"
  if command -v resetprop >/dev/null 2>&1; then
    resetprop "$k" "$v" >/dev/null 2>&1 && log "prop $k=$v (resetprop)" && return 0
  fi
  setprop "$k" "$v" >/dev/null 2>&1 && log "prop $k=$v (setprop)"
}

nearest_freq() {
  target="$1"
  list="$2"
  best=""
  best_diff=""
  for f in $list; do
    case "$f" in ''|*[!0-9]*) continue ;; esac
    diff=$((f - target))
    [ "$diff" -lt 0 ] && diff=$((-diff))
    if [ -z "$best" ] || [ "$diff" -lt "$best_diff" ]; then
      best="$f"
      best_diff="$diff"
    fi
  done
  [ -n "$best" ] && printf '%s' "$best"
}

pick_in_range() {
  low="$1"
  high="$2"
  fallback="$3"
  list="$4"
  best=""
  for f in $list; do
    case "$f" in ''|*[!0-9]*) continue ;; esac
    [ "$f" -lt "$low" ] && continue
    [ "$f" -gt "$high" ] && continue
    best="$f"
  done
  if [ -n "$best" ]; then
    printf '%s' "$best"
  else
    nearest_freq "$fallback" "$list"
  fi
}

android_version_ok() {
  sdk="$(getprop ro.build.version.sdk 2>/dev/null)"
  case "$sdk" in ''|*[!0-9]*) return 1 ;; esac
  [ "$sdk" -ge 35 ]
}

write_cpuset_group() {
  grp="$1"
  cpus="$2"
  write_if_exists "/dev/cpuset/$grp/cpus" "$cpus"
  write_if_exists "/sys/fs/cgroup/cpuset/$grp/cpus" "$cpus"
}

apply_cpuset_tuning() {
  # -------------------------- 低优先级（节能优先） --------------------------
  # 普通后台进程（如应用缓存、日志上传）：仅用低负载小核
  write_cpuset_group "background" "0-3"
  # 系统极低优先级后台（如内存交换、低功耗服务）：仅用最节能的小核
  write_cpuset_group "l-background" "0-2"
  write_cpuset_group "restricted" "0-2"
  write_cpuset_group "kswapd-like" "0-2"
  # 相机/存储后台任务：小核足够支撑，避免频繁唤醒大核
  write_cpuset_group "camera-background" "0-4"
  write_cpuset_group "storage_occupied" "0-4"

  # -------------------------- 中优先级（小核为主，按需1个大核） --------------------------
  write_cpuset_group "system-background" "0-5,6"
  write_cpuset_group "audio-app" "0-5,6"
  write_cpuset_group "scene-daemon" "0-5,6"
  write_cpuset_group "oiface_bg" "0-5,6"
  write_cpuset_group "h-background" "0-5,6"

  # -------------------------- 高优先级（流畅优先） --------------------------
  write_cpuset_group "top-app" "0-7"
  write_cpuset_group "foreground" "0-7"
  write_cpuset_group "foreground_window" "0-7"
  write_cpuset_group "display" "0-7"
  write_cpuset_group "camera-daemon" "0-7"
  write_cpuset_group "sf" "0-7"
  write_cpuset_group "oiface_fg" "0-7"
  write_cpuset_group "oiface_fg+" "0-7"
}


apply_eas_tuning() {
  write_if_exists /proc/eas_opt/eas_opt_enable 2
  write_if_exists /proc/eas_opt/group_adjust_enable 1
}

soc_is_snapdragon_8_elite() {
  soc_model="$(getprop ro.soc.model 2>/dev/null)"
  soc_name="$(getprop ro.product.board 2>/dev/null)$(getprop ro.board.platform 2>/dev/null)$(getprop ro.soc.manufacturer 2>/dev/null)"
  soc_id="$(getprop ro.boot.hardware.sku 2>/dev/null)$(getprop ro.boot.chipname 2>/dev/null)"
  all="$soc_model $soc_name $soc_id"
  case "$(printf '%s' "$all" | tr '[:upper:]' '[:lower:]')" in
    *"8 elite"*|*"sm8750"*|*"sun"*) return 0 ;;
    *) return 1 ;;
  esac
}

apply_cpu_caps() {
  policies=""
  for p in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$p" ] && policies="$policies $p"
  done

  set -- $policies
  count=$#
  [ "$count" -gt 0 ] || { log "cpufreq policies not found"; return 0; }

  i=1
  for p in $policies; do
    avail="$(read_value "$p/scaling_available_frequencies")"
    [ -n "$avail" ] || avail="$(read_value "$p/cpuinfo_max_freq")"
    [ -n "$avail" ] || { i=$((i + 1)); continue; }

    min_set=""
    max_set=""

    if [ "$count" -eq 2 ]; then
      if [ "$i" -eq 1 ]; then
        min_set="$(pick_in_range 1996800 2000000 1996800 "$avail")"
        max_set="$(pick_in_range 1996800 2016000 2000000 "$avail")"
      else
        min_set="$(pick_in_range 2380800 2438400 2419200 "$avail")"
        max_set="$(pick_in_range 2419200 2476800 2438400 "$avail")"
      fi
    elif [ "$count" -ge 3 ]; then
      if [ "$i" -eq $((count - 1)) ]; then
        min_set="$(pick_in_range 1996800 2000000 1996800 "$avail")"
        max_set="$(pick_in_range 1996800 2016000 2000000 "$avail")"
      elif [ "$i" -eq "$count" ]; then
        min_set="$(pick_in_range 2380800 2438400 2419200 "$avail")"
        max_set="$(pick_in_range 2419200 2476800 2438400 "$avail")"
      fi
    fi

    if [ -n "$max_set" ]; then
      # keep governor untouched (SCX mode), only cap frequencies
      write_if_exists "$p/scaling_min_freq" "$min_set"
      write_if_exists "$p/scaling_max_freq" "$max_set"
      log "cpu policy capped: $p min=$min_set max=$max_set"
    fi

    i=$((i + 1))
  done
}

apply_gpu_caps() {
  for g in /sys/class/kgsl/kgsl-3d0/devfreq /sys/class/devfreq/*gpu* /sys/class/devfreq/*kgsl* /sys/class/devfreq/*adreno*; do
    [ -d "$g" ] || continue
    avail="$(read_value "$g/available_frequencies")"
    minf="900000000"
    maxf="1000000000"
    if [ -n "$avail" ]; then
      minf="$(pick_in_range 880000000 930000000 900000000 "$avail")"
      maxf="$(pick_in_range 950000000 1020000000 1000000000 "$avail")"
    fi
    write_if_exists "$g/min_freq" "$minf"
    write_if_exists "$g/max_freq" "$maxf"
    write_if_exists "$g/governor" "msm-adreno-tz"
  done
  write_if_exists "/sys/class/kgsl/kgsl-3d0/devfreq/min_freq" "900000000"
  write_if_exists "/sys/class/kgsl/kgsl-3d0/devfreq/max_freq" "1000000000"
}

lock_devfreq_node() {
  node="$1"
  minv="$2"
  maxv="$3"
  boostv="$4"

  # retry writes to resist vendor services that rewrite nodes post-boot
  i=0
  while [ "$i" -lt 2 ]; do
    write_if_exists "$node/max_freq" "$maxv"
    write_if_exists "$node/min_freq" "$minv"
    write_if_exists "$node/max_freq" "$maxv"
    write_if_exists "$node/boost_freq" "$boostv"
    i=$((i + 1))
  done
}

apply_bus_dcvs_explicit_locks() {
  # DDR
  write_if_exists /sys/devices/system/cpu/bus_dcvs/DDR/boost_freq 547000
  write_if_exists /sys/devices/system/cpu/bus_dcvs/DDR/max_freq 2092000

  # DDRQOS
  write_if_exists /sys/devices/system/cpu/bus_dcvs/DDRQOS/boost_freq 1
  write_if_exists /sys/devices/system/cpu/bus_dcvs/DDRQOS/soc:qcom,memlat:ddrqos:gold/min_freq 1
  write_if_exists /sys/devices/system/cpu/bus_dcvs/DDRQOS/soc:qcom,memlat:ddrqos:gold/max_freq 1
  write_if_exists /sys/devices/system/cpu/bus_dcvs/DDRQOS/soc:qcom,memlat:ddrqos:prime/min_freq 1
  write_if_exists /sys/devices/system/cpu/bus_dcvs/DDRQOS/soc:qcom,memlat:ddrqos:prime/max_freq 1
  write_if_exists /sys/devices/system/cpu/bus_dcvs/DDRQOS/soc:qcom,memlat:ddrqos:prime-latfloor/min_freq 1
  write_if_exists /sys/devices/system/cpu/bus_dcvs/DDRQOS/soc:qcom,memlat:ddrqos:prime-latfloor/max_freq 1

  # LLCC boost control
  write_if_exists /sys/devices/system/cpu/bus_dcvs/LLCC/240b3400.qcom,bwmon-llcc-gold/use_sched_boost 1
  write_if_exists /sys/devices/system/cpu/bus_dcvs/LLCC/240b3400.qcom,bwmon-llcc-gold/sched_boost_freq 350000
  write_if_exists /sys/devices/system/cpu/bus_dcvs/LLCC/240b7400.qcom,bwmon-llcc-prime/use_sched_boost 1
  write_if_exists /sys/devices/system/cpu/bus_dcvs/LLCC/240b7400.qcom,bwmon-llcc-prime/sched_boost_freq 350000

  # LLCC global/final caps
  write_if_exists /sys/devices/system/cpu/bus_dcvs/LLCC/240b3400.qcom,bwmon-llcc-gold/max_freq 350000
  write_if_exists /sys/devices/system/cpu/bus_dcvs/LLCC/240b7400.qcom,bwmon-llcc-prime/max_freq 350000
  write_if_exists /sys/devices/system/cpu/bus_dcvs/LLCC/boost_freq 350000
  write_if_exists /sys/devices/system/cpu/bus_dcvs/LLCC/max_freq 350000
}


sweep_ddr_max_freq_2092000() {
  base="/sys/devices/system/cpu/bus_dcvs/DDR"
  [ -d "$base" ] || return 0

  # pass 1: breadth via glob recursion emulation
  count=0
  for path in "$base" "$base"/* "$base"/*/* "$base"/*/*/* "$base"/*/*/*/*; do
    [ -e "$path" ] || continue
    case "$path" in
      */max_freq)
        write_if_exists "$path" "2092000"
        count=$((count + 1))
        ;;
    esac
  done

  # pass 2: if find exists, do a full recursive sweep for deeper trees
  if command -v find >/dev/null 2>&1; then
    for f in $(find "$base" -type f -name max_freq 2>/dev/null); do
      write_if_exists "$f" "2092000"
    done
  fi

  log "DDR sweep: attempted max_freq override to 2092000 under $base"
}
apply_ddr_related() {
  # 1) generic devfreq nodes
  for d in /sys/class/devfreq/*; do
    [ -d "$d" ] || continue
    n="$(basename "$d" | tr '[:upper:]' '[:lower:]')"
    case "$n" in
      *ddrqos*|*qos*)
        lock_devfreq_node "$d" "1" "1" "1"
        ;;
      *llcc*)
        lock_devfreq_node "$d" "350000" "350000" "350000"
        ;;
      *ddr*|*cpubw*|*memlat*)
        lock_devfreq_node "$d" "547000" "2092000" "547000"
        ;;
    esac
  done

  # 2) Qualcomm bus_dcvs explicit nodes (higher priority on many ROMs)
  apply_bus_dcvs_explicit_locks

  # 3) force all DDR max_freq nodes under bus_dcvs/DDR to 2092000
  sweep_ddr_max_freq_2092000
}

apply_scx_tuning() {
  # SCX (sched_ext) tuning path
  # Kernel-dependent nodes; apply defensively.

  # enable sched_ext
  write_if_exists /sys/kernel/sched_ext/enable 1
  write_if_exists /proc/sys/kernel/sched_ext_enable 1

  # try selecting built-in scheduler profile names if exposed
  write_if_exists /sys/kernel/sched_ext/root/ops scx_lavd
  write_if_exists /sys/kernel/sched_ext/ops scx_lavd
  write_if_exists /sys/kernel/sched_ext/root/ops scx_bpfland

  # common SCX knobs seen in different kernels
  write_if_exists /sys/kernel/sched_ext/root/slice_us 4000
  write_if_exists /sys/kernel/sched_ext/root/preempt_us 1200
  write_if_exists /sys/kernel/sched_ext/root/idle_boost 0
  write_if_exists /sys/kernel/sched_ext/root/wakeup_boost 1
  write_if_exists /sys/kernel/sched_ext/root/latency_nice 0

  write_if_exists /sys/kernel/sched_ext/slice_us 4000
  write_if_exists /sys/kernel/sched_ext/preempt_us 1200
  write_if_exists /sys/kernel/sched_ext/wakeup_boost 1
  write_if_exists /sys/kernel/sched_ext/idle_boost 0

  # keep minimal WALT fallback only if SCX nodes are absent
  write_if_exists /proc/sys/kernel/sched_walt_rotate_big_tasks 1
  log "scx: tuning attempted"
}


read_mem_total_kb() {
  if [ -r /proc/meminfo ]; then
    while IFS=' ' read -r k v _; do
      case "$k" in
        MemTotal:)
          case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac
          return 0
          ;;
      esac
    done < /proc/meminfo
  fi
  echo 0
}

pick_zram_tools() {
  SWAPON_BIN=""
  SWAPOFF_BIN=""
  MKSWAP_BIN=""

  for b in /system/bin/swapon /vendor/bin/swapon /system/xbin/swapon; do
    [ -x "$b" ] && SWAPON_BIN="$b" && break
  done
  for b in /system/bin/swapoff /vendor/bin/swapoff /system/xbin/swapoff; do
    [ -x "$b" ] && SWAPOFF_BIN="$b" && break
  done
  for b in /system/bin/mkswap /vendor/bin/mkswap /system/xbin/mkswap; do
    [ -x "$b" ] && MKSWAP_BIN="$b" && break
  done

  [ -n "$SWAPON_BIN" ] || SWAPON_BIN="swapon"
  [ -n "$SWAPOFF_BIN" ] || SWAPOFF_BIN="swapoff"
  [ -n "$MKSWAP_BIN" ] || MKSWAP_BIN="mkswap"
}

apply_zram_tuning() {
  [ -e /sys/block/zram0 ] || { log "zram: zram0 not found, skip"; return 0; }

  mem_kb="$(read_mem_total_kb)"
  case "$mem_kb" in ''|*[!0-9]*) mem_kb=0 ;; esac

  # tuned by physical memory size
  if [ "$mem_kb" -le 12582912 ]; then
    zram_size_mb=8192
  elif [ "$mem_kb" -le 16777216 ]; then
    zram_size_mb=11366
  else
    zram_size_mb=12288
  fi

  pick_zram_tools

  # disable active swaps first
  if [ -r /proc/swaps ]; then
    while IFS=' ' read -r dev _; do
      case "$dev" in
        /dev/block/zram*) "$SWAPOFF_BIN" "$dev" >/dev/null 2>&1 ;;
      esac
    done < /proc/swaps
  fi

  # reset zram devices to avoid stale settings
  for z in /sys/block/zram*; do
    [ -d "$z" ] || continue
    write_if_exists "$z/reset" 1
  done

  write_if_exists /sys/block/zram0/comp_algorithm lz4
  write_if_exists /sys/block/zram0/disksize "${zram_size_mb}M"
  write_if_exists /sys/kernel/mm/swap/vma_ra_enabled 1
  write_if_exists /proc/sys/vm/page-cluster 1

  "$MKSWAP_BIN" /dev/block/zram0 >/dev/null 2>&1
  "$SWAPON_BIN" /dev/block/zram0 -p 32767 >/dev/null 2>&1

  log "zram: size=${zram_size_mb}MB alg=lz4 priority=32767"
}

apply_render_memory_props() {
  # Vulkan / RenderEngine
  set_prop_safe ro.hwui.use_vulkan true
  set_prop_safe debug.hwui.renderer skiavk
  set_prop_safe debug.renderengine.backend skiavkthreaded
  set_prop_safe debug.renderengine.vulkan true
  set_prop_safe debug.stagefright.renderengine.backend threaded

  # Memory / LMK
  set_prop_safe ro.sys.fw.bg_apps_limit 32768
  set_prop_safe ro.vendor.qti.sys.fw.bservice_limit 32768
  set_prop_safe persist.sys.mms.bg_apps_limit 32768
  set_prop_safe ro.lmk.use_psi true
  set_prop_safe ro.lmk.low 1001
  set_prop_safe ro.lmk.medium 906
  set_prop_safe ro.lmk.psi_partial_stall_ms 250
  set_prop_safe ro.lmk.psi_complete_stall_ms 700
  set_prop_safe ro.lmk.pressure_after_kill_min_score 800
  set_prop_safe ro.lmk.thrashing_limit 100
  set_prop_safe ro.lmk.thrashing_limit_decay 10
  set_prop_safe ro.lmk.use_minfree_levels false
  set_prop_safe ro.lmk.swap_free_low_percentage 1
  set_prop_safe ro.lmk.swap_util_max 100
  set_prop_safe ro.lmk.swap_is_low_kill_enable 0
  set_prop_safe ro.lmk.critical 800
  set_prop_safe ro.lmk.critical_upgrade false
  set_prop_safe ro.lmk.upgrade_pressure 100
  set_prop_safe ro.lmk.downgrade_pressure 100
  set_prop_safe ro.lmk.kill_heaviest_task false
  set_prop_safe ro.lmk.kill_timeout_ms 200
  set_prop_safe ro.lmk.enhance_batch_kill false
  set_prop_safe ro.lmk.enable_adaptive_lmk false
  set_prop_safe ro.lmk.swap_compression_ratio 4
  set_prop_safe ro.lmk.lowmem_min_oom_score 1001
  set_prop_safe ro.lmk.direct_reclaim_threshold_ms 0
  set_prop_safe persist.sys.preload.enable false
  set_prop_safe persist.vendor.enable.preload false
  set_prop_safe sys.gcsupression.optimize.enable false
  set_prop_safe ro.lmk.limit_killing_array_kb 409600,358400,281600,204800
  set_prop_safe sys.oplus.lmk.change_limit 1
  set_prop_safe sys.sysctl.extra_free_kbytes 58898
}

main() {
  log "tune entry: MODDIR=$MODDIR"

  if ! android_version_ok; then
    sdk="$(getprop ro.build.version.sdk 2>/dev/null)"
    log "android sdk=$sdk < 35, skip tuning"
    return 0
  fi

  if ! soc_is_snapdragon_8_elite; then
    log "unsupported soc, skip tuning"
    return 0
  fi

  log "snapdragon 8 elite profile start"
  apply_render_memory_props
  apply_zram_tuning
  apply_cpu_caps
  apply_gpu_caps
  apply_ddr_related
  apply_cpuset_tuning
  apply_eas_tuning
  apply_scx_tuning
  log "snapdragon 8 elite profile complete"
}

main "$@"
