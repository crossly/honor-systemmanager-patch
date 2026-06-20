#!/system/bin/sh

MODDIR=${0%/*}
LOG="/data/adb/honor-systemmanager-patch.log"
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

until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done

echo "[$(date '+%F %T')] boot completed" >> "$LOG"

# Late pass only records and re-applies the file for next boot. It intentionally
# avoids stop/start framework loops during normal boot.
for profile in $PROFILES; do
  MODE="$(profile_mode "$profile")"
  echo "[$(date '+%F %T')] late profile=$profile mode=$MODE" >> "$LOG"
  if [ "$MODE" = "block" ] || [ "$MODE" = "restore" ]; then
    MODDIR="$MODDIR" sh "$MODDIR/common/patch.sh" "$MODE" "$profile" >/dev/null 2>&1
  fi
done
