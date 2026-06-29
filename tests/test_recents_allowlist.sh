#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TARGETS="$ROOT/module/common/targets.txt"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_target() {
  profile="$1"
  package="$2"
  component="$3"
  grep -Fqx "$profile|$package|$component" "$TARGETS" || {
    fail "expected target: $profile|$package|$component"
  }
}

assert_not_target_component() {
  component="$1"
  if awk -F'|' -v component="$component" 'NF >= 3 && $3 == component { found = 1 } END { exit found ? 0 : 1 }' "$TARGETS"; then
    fail "component must stay active for Recents swipe-up cleanup: $component"
  fi
}

assert_not_target_component "com.hihonor.systemmanager.service.MainService"
assert_not_target_component "com.hihonor.systemmanager.spacecleanner.service.AppCleanUpService"

assert_target "background" "com.hihonor.systemmanager" "com.hihonor.systemmanager.power.service.BgPowerManagerService"
assert_target "powerkit" "com.hihonor.powergenie" "com.hihonor.android.powerkit.PowerKitService"

echo "recents allowlist test passed"
