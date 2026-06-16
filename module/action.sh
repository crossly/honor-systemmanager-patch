#!/system/bin/sh

MODDIR=${0%/*}
MODE_FILE="$MODDIR/mode"
MODE="$(cat "$MODE_FILE" 2>/dev/null)"

if [ "$MODE" = "block" ]; then
  NEW_MODE="restore"
else
  NEW_MODE="block"
fi

echo "$NEW_MODE" > "$MODE_FILE"
echo "Switching HONOR System Manager Patch to: $NEW_MODE"
MODDIR="$MODDIR" sh "$MODDIR/common/patch.sh" "$NEW_MODE" || exit 1
echo "Mode changed. Reboot to make PackageManager reload restrictions cleanly."
echo
MODDIR="$MODDIR" sh "$MODDIR/common/status.sh" || true
