#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
VERSION="$(awk -F= '$1 == "version" { print $2 }' "$ROOT/module/module.prop")"
OUT="$ROOT/dist/honor-systemmanager-patch-$VERSION.zip"

mkdir -p "$ROOT/dist"
rm -f "$OUT"

chmod 0755 "$ROOT/module/META-INF/com/google/android/update-binary" \
  "$ROOT/module/common/patch.sh" \
  "$ROOT/module/common/status.sh" \
  "$ROOT/module/customize.sh" \
  "$ROOT/module/post-fs-data.sh" \
  "$ROOT/module/service.sh" \
  "$ROOT/module/uninstall.sh"

cd "$ROOT/module"
zip -r "$OUT" . -x '*.DS_Store' '__MACOSX/*'

echo "$OUT"
