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

enter_light_doze() {
  cmd deviceidle enable >/dev/null 2>&1
  cmd deviceidle step light >/dev/null 2>&1
  cmd deviceidle force-idle light >/dev/null 2>&1
}

enter_deep_doze() {
  cmd deviceidle enable >/dev/null 2>&1
  cmd deviceidle force-idle deep >/dev/null 2>&1
}

exit_doze() {
  cmd deviceidle unforce >/dev/null 2>&1
  cmd deviceidle step >/dev/null 2>&1
}

last_awake="$(date +%s 2>/dev/null)"
light_applied=0

a=0
while [ "$a" -lt 3600 ]; do
  # run up to 1 hour; service relaunches on next boot
  if screen_is_on; then
    [ "$light_applied" -eq 1 ] && log "doze: wake detected, exit doze"
    light_applied=0
    last_awake="$(date +%s 2>/dev/null)"
    exit_doze
  else
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
      log "doze: screen off >=300s -> deep doze"
      enter_deep_doze
    fi
  fi

  sleep 5
  a=$((a + 1))
done

rm -f "$PID_FILE" 2>/dev/null
