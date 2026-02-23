#!/system/bin/sh

resolve_moddir() {
  d="${0%/*}"
  [ -n "$d" ] && [ -d "$d" ] && { echo "$d"; return 0; }

  for c in \
    /data/adb/modules/sd8e_tweaker \
    /data/adb/modules_update/sd8e_tweaker \
    /data/adb/ksu/modules/sd8e_tweaker; do
    [ -d "$c" ] && { echo "$c"; return 0; }
  done

  echo "."
}

MODDIR="$(resolve_moddir)"
LOG_DIR="/data/adb/ksu_tweaker"
LOG_FILE="$LOG_DIR/tune.log"

mkdir -p "$LOG_DIR" 2>/dev/null

# wait boot completed (no seq dependency)
i=0
while [ "$i" -lt 180 ]; do
  [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ] && break
  sleep 1
  i=$((i + 1))
done

if [ -f "$MODDIR/tune.sh" ]; then
  sh "$MODDIR/tune.sh" >>"$LOG_FILE" 2>&1
else
  echo "$(date '+%F %T' 2>/dev/null) [E] tune.sh not found under $MODDIR" >>"$LOG_FILE"
fi
