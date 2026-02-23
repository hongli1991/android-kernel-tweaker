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


write_cpuset_group() {
  grp="$1"
  cpus="$2"

  write_if_exists "/dev/cpuset/$grp/cpus" "$cpus"
  write_if_exists "/sys/fs/cgroup/cpuset/$grp/cpus" "$cpus"
}

apply_cpuset_tuning() {
  # Requested mapping
  write_cpuset_group "background" "0-3"
  write_cpuset_group "system-background" "2-4"
  write_cpuset_group "top-app" "0-5"
  write_cpuset_group "foreground" "0-5"

  # Extended mapping for common Android/OPlus groups (smoothness + efficiency)
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

apply_ddr_related() {
  for d in /sys/class/devfreq/*; do
    [ -d "$d" ] || continue
    n="$(basename "$d" | tr '[:upper:]' '[:lower:]')"
    case "$n" in
      *ddrqos*|*qos*)
        write_if_exists "$d/min_freq" "1"
        write_if_exists "$d/max_freq" "1"
        write_if_exists "$d/boost_freq" "1"
        ;;
      *llcc*)
        write_if_exists "$d/max_freq" "350000"
        write_if_exists "$d/min_freq" "350000"
        write_if_exists "$d/boost_freq" "350000"
        ;;
      *ddr*|*cpubw*|*memlat*)
        write_if_exists "$d/max_freq" "209200"
        write_if_exists "$d/min_freq" "547000"
        write_if_exists "$d/boost_freq" "547000"
        ;;
    esac
  done
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

main() {
  log "tune entry: MODDIR=$MODDIR"
  if ! soc_is_snapdragon_8_elite; then
    log "unsupported soc, skip tuning"
    return 0
  fi

  log "snapdragon 8 elite profile start"
  apply_cpu_caps
  apply_gpu_caps
  apply_ddr_related
  apply_cpuset_tuning
  apply_walt_sched
  log "snapdragon 8 elite profile complete"
}

main "$@"
