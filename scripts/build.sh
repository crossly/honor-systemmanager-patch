#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUT="$ROOT/dist/honor-systemmanager-patch-v1.1.0.zip"

mkdir -p "$ROOT/dist"
rm -f "$OUT"

chmod 0755 "$ROOT/module/META-INF/com/google/android/update-binary" \
  "$ROOT/module/action.sh" \
  "$ROOT/module/common/patch.sh" \
  "$ROOT/module/common/status.sh" \
  "$ROOT/module/customize.sh" \
  "$ROOT/module/post-fs-data.sh" \
  "$ROOT/module/service.sh" \
  "$ROOT/module/uninstall.sh"

cd "$ROOT/module"
zip -r "$OUT" .

echo "$OUT"
