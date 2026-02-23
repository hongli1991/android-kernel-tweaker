#!/system/bin/sh
MODDIR="${0%/*}"
LOG_DIR="/data/adb/ksu_tweaker"
LOG_FILE="$LOG_DIR/tune.log"

mkdir -p "$LOG_DIR" 2>/dev/null

# wait boot completed
for _i in $(seq 1 180); do
  [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ] && break
  sleep 1
done

sh "$MODDIR/tune.sh" >>"$LOG_FILE" 2>&1
