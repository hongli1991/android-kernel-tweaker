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
  write_cpuset_group "background" "0-3"
  write_cpuset_group "system-background" "2-4"
  write_cpuset_group "top-app" "0-5"
  write_cpuset_group "foreground" "0-5"

  write_cpuset_group "foreground_window" "0-5"
  write_cpuset_group "display" "0-5"
  write_cpuset_group "audio-app" "0-4"
  write_cpuset_group "camera-background" "0-3"
  write_cpuset_group "camera-daemon" "0-5"
  write_cpuset_group "h-background" "0-3"
  write_cpuset_group "l-background" "0-2"
  write_cpuset_group "restricted" "0-2"
  write_cpuset_group "kswapd-like" "0-2"
  write_cpuset_group "oiface_bg" "0-3"
  write_cpuset_group "oiface_fg" "0-5"
  write_cpuset_group "oiface_fg+" "0-6"
  write_cpuset_group "scene-daemon" "0-4"
  write_cpuset_group "sf" "0-5"
  write_cpuset_group "storage_occupied" "0-3"
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
      write_if_exists "$p/scaling_governor" "schedutil"
      write_if_exists "$p/scaling_min_freq" "$min_set"
      write_if_exists "$p/scaling_max_freq" "$max_set"
      su="$p/schedutil"
      case "$i" in
        1)
          write_if_exists "$su/up_rate_limit_us" "12000"
          write_if_exists "$su/down_rate_limit_us" "35000"
          ;;
        *)
          write_if_exists "$su/up_rate_limit_us" "4000"
          write_if_exists "$su/down_rate_limit_us" "22000"
          ;;
      esac
      write_if_exists "$su/iowait_boost_enable" "1"
      log "cpu policy tuned: $p min=$min_set max=$max_set"
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
  while [ "$i" -lt 3 ]; do
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
  write_if_exists /sys/devices/system/cpu/bus_dcvs/DDR/max_freq 547000

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
        lock_devfreq_node "$d" "547000" "547000" "547000"
        ;;
    esac
  done

  # 2) Qualcomm bus_dcvs explicit nodes (higher priority on many ROMs)
  apply_bus_dcvs_explicit_locks
}

apply_walt_sched() {
  write_if_exists /proc/sys/kernel/sched_util_clamp_min "0"
  write_if_exists /proc/sys/kernel/sched_util_clamp_max "1024"
  write_if_exists /proc/sys/kernel/sched_coloc_downmigrate_ns "4000000"
  write_if_exists /proc/sys/kernel/sched_coloc_busy_hyst_cpu_ns "39000000"
  write_if_exists /proc/sys/kernel/sched_busy_hyst_cpu_ns "5000000"
  write_if_exists /proc/sys/kernel/sched_min_task_util_for_boost "15"
  write_if_exists /proc/sys/kernel/sched_walt_rotate_big_tasks "1"
  write_if_exists /proc/sys/kernel/sched_group_upmigrate "95"
  write_if_exists /proc/sys/kernel/sched_group_downmigrate "85"
  write_if_exists /proc/sys/kernel/sched_upmigrate "95 95"
  write_if_exists /proc/sys/kernel/sched_downmigrate "75 85"
  write_if_exists /proc/sys/kernel/sched_adaptive_noise_floor "128"
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
  apply_cpu_caps
  apply_gpu_caps
  apply_ddr_related
  apply_cpuset_tuning
  apply_walt_sched
  log "snapdragon 8 elite profile complete"
}

main "$@"
