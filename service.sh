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

LOG_DIR=/data/adb/ksu_tweaker
LOG_FILE=$LOG_DIR/tune.log
DOZE_PID_FILE=$LOG_DIR/doze_daemon.pid
mkdir -p "$LOG_DIR" 2>/dev/null

# wait boot completed (max 180s)
i=0
while [ "$i" -lt 180 ]
do
  if [ "$(getprop sys.boot_completed 2>/dev/null)" = "1" ]; then
    break
  fi
  sleep 1
  i=$((i + 1))
done

if [ -f "$MODDIR/tune.sh" ]; then
  sh "$MODDIR/tune.sh" >>"$LOG_FILE" 2>&1
else
  echo "$(date '+%F %T' 2>/dev/null) [E] tune.sh not found under $MODDIR" >>"$LOG_FILE"
fi

if [ -f "$MODDIR/scripts/doze_daemon.sh" ]; then
  running=0
  if [ -f "$DOZE_PID_FILE" ]; then
    read -r oldpid < "$DOZE_PID_FILE" 2>/dev/null
    [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null && running=1
  fi
  if [ "$running" -eq 0 ]; then
    sh "$MODDIR/scripts/doze_daemon.sh" >>"$LOG_FILE" 2>&1 &
    echo "$(date '+%F %T' 2>/dev/null) doze daemon started pid=$!" >>"$LOG_FILE"
  fi
fi
