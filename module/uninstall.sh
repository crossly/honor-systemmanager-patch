#!/system/bin/sh

MODDIR=${0%/*}
echo "restore" > "$MODDIR/mode"
mkdir -p "$MODDIR/modes"
for profile in security background powerkit; do
  echo "restore" > "$MODDIR/modes/$profile"
  MODDIR="$MODDIR" sh "$MODDIR/common/patch.sh" restore "$profile" >/dev/null 2>&1 || true
done
