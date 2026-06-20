#!/system/bin/sh

MODDIR=${0%/*}
PROFILES="security background powerkit"

profile_mode() {
  profile="$1"
  mode="$(cat "$MODDIR/modes/$profile" 2>/dev/null)"
  if [ "$mode" = "block" ] || [ "$mode" = "restore" ]; then
    echo "$mode"
    return
  fi
  cat "$MODDIR/mode" 2>/dev/null || echo ""
}

# PackageManager reads package-restrictions early. Run here so reboot applies
# the selected state without touching the system partition.
for profile in $PROFILES; do
  MODE="$(profile_mode "$profile")"
  if [ "$MODE" = "block" ] || [ "$MODE" = "restore" ]; then
    MODDIR="$MODDIR" sh "$MODDIR/common/patch.sh" "$MODE" "$profile" >/dev/null 2>&1
  fi
done
