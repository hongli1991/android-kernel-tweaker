#!/system/bin/sh

# Let KernelSU/Magisk installer perform standard extraction.
# This avoids missing module.prop on some Hybrid Mount installer paths.
SKIPUNZIP=0

print_modname() {
  ui_print "*******************************"
  ui_print " Snapdragon 8 Elite Tweaker"
  ui_print " KernelSU / Magisk Module"
  ui_print "我相信会再次看到蓝天 鲜花挂满枝头"
  ui_print "*******************************"
}

on_install() {
  ui_print "- Using standard installer extraction"
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644

  [ -f "$MODPATH/service.sh" ] && set_perm "$MODPATH/service.sh" 0 0 0755
  [ -f "$MODPATH/post-fs-data.sh" ] && set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
  [ -f "$MODPATH/uninstall.sh" ] && set_perm "$MODPATH/uninstall.sh" 0 0 0755
  [ -f "$MODPATH/tune.sh" ] && set_perm "$MODPATH/tune.sh" 0 0 0755

  [ -d "$MODPATH/scripts" ] && set_perm_recursive "$MODPATH/scripts" 0 0 0755 0644
}
