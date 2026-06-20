#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
HTML="$ROOT/module/webroot/index.html"
JS="$ROOT/module/webroot/scripts.js"
CSS="$ROOT/module/webroot/styles.css"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  file="$1"
  needle="$2"
  grep -Fq "$needle" "$file" || fail "expected $file to contain $needle"
}

assert_contains "$HTML" 'class="topbar"'
assert_contains "$HTML" 'data-status="security"'
assert_contains "$HTML" 'data-status="background"'
assert_contains "$HTML" 'data-status="powerkit"'
assert_contains "$HTML" 'data-profile-title="security"'
assert_contains "$JS" 'setProfileStatus'
assert_contains "$JS" 'refreshModes'
assert_contains "$CSS" '.mode-pill'
assert_contains "$CSS" '.profile-row'

echo "webui structure test passed"
