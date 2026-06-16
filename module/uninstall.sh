#!/system/bin/sh

MODDIR=${0%/*}
echo "restore" > "$MODDIR/mode"
MODDIR="$MODDIR" "$MODDIR/common/patch.sh" restore >/dev/null 2>&1 || true
