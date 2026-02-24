#!/system/bin/sh

LOG_DIR=/data/adb/ksu_tweaker
LOG_FILE=$LOG_DIR/tune.log
PID_FILE=$LOG_DIR/log_cleaner.pid
MAX_BYTES=1048576
CHECK_INTERVAL=1800

mkdir -p "$LOG_DIR" 2>/dev/null
[ -f "$LOG_FILE" ] || : > "$LOG_FILE"
echo $$ > "$PID_FILE" 2>/dev/null

log() {
  printf '%s %s\n' "$(date '+%F %T' 2>/dev/null)" "$*" >>"$LOG_FILE"
}

truncate_log_if_needed() {
  size=0
  if command -v wc >/dev/null 2>&1; then
    size="$(wc -c < "$LOG_FILE" 2>/dev/null)"
  fi
  case "$size" in ''|*[!0-9]*) size=0 ;; esac

  if [ "$size" -gt "$MAX_BYTES" ]; then
    if command -v tail >/dev/null 2>&1; then
      tail -n 2000 "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null
      cat "$LOG_FILE.tmp" > "$LOG_FILE" 2>/dev/null
      rm -f "$LOG_FILE.tmp" 2>/dev/null
    else
      : > "$LOG_FILE"
    fi
    log "log-cleaner: trimmed log, old_size=$size"
  fi
}

# long-running lightweight cleaner
while :; do
  truncate_log_if_needed
  sleep "$CHECK_INTERVAL"
done
