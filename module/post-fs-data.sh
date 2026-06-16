#!/system/bin/sh

MODDIR=${0%/*}
MODE_FILE="$MODDIR/mode"
MODE="$(cat "$MODE_FILE" 2>/dev/null)"

[ "$MODE" = "block" ] || [ "$MODE" = "restore" ] || exit 0

# PackageManager reads package-restrictions early. Run here so reboot applies
# the selected state without touching the system partition.
MODDIR="$MODDIR" sh "$MODDIR/common/patch.sh" "$MODE" >/dev/null 2>&1
