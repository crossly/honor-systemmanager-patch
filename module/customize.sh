#!/system/bin/sh

SKIPMOUNT=true
PROPFILE=false
POSTFSDATA=true
LATESTARTSERVICE=true

ui_print() {
  echo "$1"
}

choose_mode() {
  ui_print " "
  ui_print "Choose install mode:"
  ui_print "  Vol Up   = block HONOR System Manager services"
  ui_print "  Vol Down = restore HONOR System Manager services"
  ui_print "Waiting 15 seconds; default is Vol Up/block."

  key=""
  if command -v timeout >/dev/null 2>&1 && command -v getevent >/dev/null 2>&1; then
    key="$(timeout 15 getevent -ql 2>/dev/null | grep -m 1 -E 'KEY_VOLUMEUP|KEY_VOLUMEDOWN')"
  fi

  case "$key" in
    *KEY_VOLUMEDOWN*)
      echo "restore" > "$MODPATH/mode"
      ui_print "Selected: restore services"
      ;;
    *)
      echo "block" > "$MODPATH/mode"
      ui_print "Selected: block services"
      ;;
  esac
}

set_permissions() {
  set_perm_recursive "$MODPATH" 0 0 0755 0644
  set_perm "$MODPATH/common/patch.sh" 0 0 0755
  set_perm "$MODPATH/common/status.sh" 0 0 0755
  set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
  set_perm "$MODPATH/service.sh" 0 0 0755
  set_perm "$MODPATH/action.sh" 0 0 0755
  set_perm "$MODPATH/uninstall.sh" 0 0 0755
}

on_install() {
  ui_print " "
  ui_print "Installing HONOR System Manager Patch"
  ui_print "Target: MagicOS / HONOR com.hihonor.systemmanager"
  unzip -o "$ZIPFILE" 'common/*' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'webroot/*' -d "$MODPATH" >&2
  unzip -o "$ZIPFILE" 'module.prop' 'post-fs-data.sh' 'service.sh' 'action.sh' 'uninstall.sh' -d "$MODPATH" >&2
  choose_mode
  ui_print "Applying selected package-restrictions patch once..."
  MODDIR="$MODPATH" sh "$MODPATH/common/patch.sh" "$(cat "$MODPATH/mode")" || ui_print "Patch apply failed during install; it will retry on boot."
  ui_print "Reboot required for PackageManager to reload service states cleanly."
}
