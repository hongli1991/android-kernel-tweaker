#!/system/bin/sh

SKIPUNZIP=1

print_modname() {
  ui_print "*******************************"
  ui_print " Snapdragon 8 Elite Tweaker"
  ui_print " KernelSU / Magisk Module"
  ui_print "*******************************"
}

on_install() {
  ui_print "- Extracting module files"
  unzip -o "$ZIPFILE" -x 'META-INF/*' -d "$MODPATH" >&2
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  set_perm "$MODPATH/service.sh" 0 0 0755
  set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
  set_perm "$MODPATH/uninstall.sh" 0 0 0755
  set_perm "$MODPATH/tune.sh" 0 0 0755
  set_perm_recursive "$MODPATH/scripts" 0 0 0755 0644
}
