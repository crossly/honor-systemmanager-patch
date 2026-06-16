#!/system/bin/sh

MODDIR=${0%/*}
LOG="/data/adb/honor-systemmanager-patch.log"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
  sleep 2
done

MODE="$(cat "$MODDIR/mode" 2>/dev/null)"
echo "[$(date '+%F %T')] boot completed, mode=$MODE" >> "$LOG"

# Late pass only records and re-applies the file for next boot. It intentionally
# avoids stop/start framework loops during normal boot.
if [ "$MODE" = "block" ] || [ "$MODE" = "restore" ]; then
  MODDIR="$MODDIR" sh "$MODDIR/common/patch.sh" "$MODE" >/dev/null 2>&1
fi
