#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/honor-systemmanager-patch-test.$$"
MODULE="$TMP/module"
DATA_ROOT="$TMP/data"
WORK_ROOT="$TMP/work"

cleanup() {
  rm -rf "$TMP"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  file="$1"
  needle="$2"
  grep -Fq "$needle" "$file" || fail "expected $file to contain $needle"
}

assert_not_contains() {
  file="$1"
  needle="$2"
  if grep -Fq "$needle" "$file"; then
    fail "expected $file not to contain $needle"
  fi
}

mkdir -p "$MODULE" "$DATA_ROOT/system/users/0" "$DATA_ROOT/system/users/128" "$WORK_ROOT"
cp -R "$ROOT/module/." "$MODULE/"
cp "$ROOT/tests/fixtures/package-restrictions.xml" "$DATA_ROOT/system/users/0/package-restrictions.xml"
cp "$ROOT/tests/fixtures/package-restrictions.xml" "$DATA_ROOT/system/users/128/package-restrictions.xml"

PATH="$ROOT/tests/fakebin:$PATH" \
  MODDIR="$MODULE" DATA_ROOT="$DATA_ROOT" WORK_ROOT="$WORK_ROOT" \
  sh "$MODULE/common/patch.sh" block background

assert_contains "$DATA_ROOT/system/users/0/package-restrictions.xml" "com.hihonor.systemmanager.power.service.BgPowerManagerService"
assert_contains "$DATA_ROOT/system/users/0/package-restrictions.xml" "com.hihonor.systemmanager.power.service.SavePowerManagerService"
assert_not_contains "$DATA_ROOT/system/users/0/package-restrictions.xml" "com.hihonor.securitycenter.mainservice.HwSecService"
assert_not_contains "$DATA_ROOT/system/users/0/package-restrictions.xml" "com.hihonor.android.powerkit.PowerKitService"

PATH="$ROOT/tests/fakebin:$PATH" \
  MODDIR="$MODULE" DATA_ROOT="$DATA_ROOT" WORK_ROOT="$WORK_ROOT" \
  sh "$MODULE/common/patch.sh" block powerkit

assert_contains "$DATA_ROOT/system/users/0/package-restrictions.xml" "com.hihonor.android.powerkit.PowerKitService"
assert_contains "$DATA_ROOT/system/users/128/package-restrictions.xml" "com.hihonor.android.powerkit.PowerKitService"

PATH="$ROOT/tests/fakebin:$PATH" \
  MODDIR="$MODULE" DATA_ROOT="$DATA_ROOT" WORK_ROOT="$WORK_ROOT" \
  sh "$MODULE/common/patch.sh" restore background

assert_not_contains "$DATA_ROOT/system/users/0/package-restrictions.xml" "com.hihonor.systemmanager.power.service.BgPowerManagerService"
assert_contains "$DATA_ROOT/system/users/0/package-restrictions.xml" "com.hihonor.android.powerkit.PowerKitService"
assert_contains "$DATA_ROOT/system/users/0/package-restrictions.xml" "com.example.ExistingDisabledService"

status_output="$TMP/status.out"
PATH="$ROOT/tests/fakebin:$PATH" \
  MODDIR="$MODULE" DATA_ROOT="$DATA_ROOT" WORK_ROOT="$WORK_ROOT" \
  sh "$MODULE/common/status.sh" all > "$status_output"

assert_contains "$status_output" "Profile: background"
assert_contains "$status_output" "Profile: powerkit"
assert_contains "$status_output" "com.hihonor.powergenie"
assert_contains "$status_output" "summary:"

echo "profiles test passed"
