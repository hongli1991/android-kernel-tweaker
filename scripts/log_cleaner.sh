#!/system/bin/sh

LOG_DIR=/data/adb/ksu_tweaker
LOG_FILE=$LOG_DIR/tune.log
PID_FILE=$LOG_DIR/log_cleaner.pid
MAX_BYTES=1048576
# 12h
CHECK_INTERVAL=43200

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
      tail -n 1200 "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null
      cat "$LOG_FILE.tmp" > "$LOG_FILE" 2>/dev/null
      rm -f "$LOG_FILE.tmp" 2>/dev/null
    else
      : > "$LOG_FILE"
    fi
    log "log-cleaner: trimmed log, old_size=$size"
  fi
}

# run once at startup, then every 12h
truncate_log_if_needed
while :; do
  sleep "$CHECK_INTERVAL"
  truncate_log_if_needed
done
