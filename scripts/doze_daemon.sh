#!/system/bin/sh

LOG_DIR=/data/adb/ksu_tweaker
LOG_FILE=$LOG_DIR/tune.log
PID_FILE=$LOG_DIR/doze_daemon.pid
mkdir -p "$LOG_DIR" 2>/dev/null

echo $$ > "$PID_FILE" 2>/dev/null

log() {
  printf '%s %s\n' "$(date '+%F %T' 2>/dev/null)" "$*" >>"$LOG_FILE"
}

screen_is_on() {
  state="$(dumpsys power 2>/dev/null)"
  case "$state" in
    *"Display Power: state=ON"*|*"mWakefulness=Awake"*) return 0 ;;
    *) return 1 ;;
  esac
}

setup_doze_policy() {
  # more aggressive entry, but keep maintenance windows for normal system behavior
  settings put global device_idle_constants     inactive_to=300000,light_after_inactive_to=60000,idle_pending_to=30000,max_idle_pending_to=120000,idle_to=1800000,max_idle_to=21600000,min_light_maintenance_time=5000,min_deep_maintenance_time=30000 >/dev/null 2>&1

  # keep critical IM/music alive
  for pkg in     com.tencent.mm     com.tencent.mobileqq     com.tencent.qqmusic     com.netease.cloudmusic     com.kugou.android     com.spotify.music; do
    cmd deviceidle whitelist +"$pkg" >/dev/null 2>&1
    cmd deviceidle except-idle-whitelist +"$pkg" >/dev/null 2>&1
  done

  cmd deviceidle enable >/dev/null 2>&1
}

enter_light_doze() {
  cmd deviceidle force-idle light >/dev/null 2>&1
}

enter_deep_doze() {
  cmd deviceidle force-idle deep >/dev/null 2>&1
}

exit_doze() {
  cmd deviceidle unforce >/dev/null 2>&1
}

setup_doze_policy
last_awake="$(date +%s 2>/dev/null)"
light_applied=0
while :; do
  if screen_is_on; then
    [ "$light_applied" -eq 1 ] && log "doze: wake detected, exit doze"
    light_applied=0
    last_awake="$(date +%s 2>/dev/null)"
    exit_doze
    sleep 120
    continue
  fi

  now="$(date +%s 2>/dev/null)"
  [ -n "$now" ] || now=0
  [ -n "$last_awake" ] || last_awake=0

  if [ "$light_applied" -eq 0 ]; then
    log "doze: screen off -> light doze"
    enter_light_doze
    light_applied=1
  fi

  off_dur=$((now - last_awake))
  if [ "$off_dur" -ge 300 ]; then
    enter_deep_doze
  fi

  sleep 30
done
