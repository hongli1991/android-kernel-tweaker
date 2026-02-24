#!/system/bin/sh
MODDIR="${0%/*}"
chmod 0755 "$MODDIR"/*.sh 2>/dev/null
chmod -R 0755 "$MODDIR"/scripts 2>/dev/null
mkdir -p /data/adb/ksu_tweaker 2>/dev/null
