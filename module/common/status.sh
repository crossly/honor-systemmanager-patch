#!/system/bin/sh

MODDIR="${MODDIR:-${0%/*}/..}"
PROFILE="${1:-all}"
USERS="0 128"
DATA_ROOT="${DATA_ROOT:-/data}"
WORK_ROOT="${WORK_ROOT:-/data/local/tmp}"
TARGETS="$MODDIR/common/targets.txt"
WORK="$WORK_ROOT/honor-systemmanager-patch-status"

need_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: $1 not found"
    exit 1
  }
}

selected_expr='
  function selected(profile,    n, i, arr) {
    if (profiles == "all") return 1
    n = split(profiles, arr, ",")
    for (i = 1; i <= n; i++) if (arr[i] == profile) return 1
    return 0
  }
'

list_profiles() {
  awk -F'|' -v profiles="$PROFILE" "$selected_expr"'
    NF >= 3 && selected($1) && !seen[$1]++ { print $1 }
  ' "$TARGETS"
}

list_packages_for_profile() {
  profile="$1"
  awk -F'|' -v profile="$profile" '
    NF >= 3 && $1 == profile && !seen[$2]++ { print $2 }
  ' "$TARGETS"
}

list_components() {
  profile="$1"
  pkg="$2"
  awk -F'|' -v profile="$profile" -v pkg="$pkg" '
    NF >= 3 && $1 == profile && $2 == pkg { print $3 }
  ' "$TARGETS"
}

package_block() {
  pkg="$1"
  xml="$2"
  sed -n "/<pkg .*name=\"$pkg\"/,/<\\/pkg>/p" "$xml"
}

disabled_block() {
  sed -n '/<disabled-components>/,/<\/disabled-components>/p'
}

mode_for_profile() {
  profile="$1"
  cat "$MODDIR/modes/$profile" 2>/dev/null || cat "$MODDIR/mode" 2>/dev/null || echo unknown
}

check_user_profile_pkg() {
  user="$1"
  profile="$2"
  pkg="$3"
  src="$DATA_ROOT/system/users/$user/package-restrictions.xml"
  xml="$WORK/package-restrictions-$user.xml"
  blocked=0
  total=0

  echo "User $user package $pkg:"
  if [ ! -f "$src" ]; then
    echo "  package restrictions missing"
    return
  fi

  abx2xml "$src" "$xml" >/dev/null 2>&1 || {
    echo "  cannot decode package restrictions"
    return
  }

  pkg_block="$(package_block "$pkg" "$xml" | disabled_block)"
  while IFS= read -r component; do
    [ -n "$component" ] || continue
    total=$((total + 1))
    if echo "$pkg_block" | grep -q "name=\"$component\""; then
      echo "  blocked: $component"
      blocked=$((blocked + 1))
    else
      echo "  active : $component"
    fi
  done <<EOF
$(list_components "$profile" "$pkg")
EOF

  echo "  summary: $blocked/$total blocked"
}

check_running_services_for_profile_pkg() {
  profile="$1"
  pkg="$2"
  echo "Running target services for $profile / $pkg:"
  found=0
  dump="$(dumpsys activity services "$pkg" 2>/dev/null || true)"
  while IFS= read -r component; do
    [ -n "$component" ] || continue
    short="$component"
    case "$component" in
      "$pkg".*)
        short=".${component#$pkg.}"
        ;;
    esac
    if echo "$dump" | grep -q "$short\\|$component"; then
      echo "  running: $component"
      found=$((found + 1))
    fi
  done <<EOF
$(list_components "$profile" "$pkg")
EOF
  [ "$found" -eq 0 ] && echo "  none"
}

need_bin abx2xml
need_bin awk
need_bin sed
need_bin grep

[ -f "$TARGETS" ] || {
  echo "ERROR: targets missing: $TARGETS"
  exit 1
}

mkdir -p "$WORK"
echo "HONOR System Manager Patch status"
echo "Selected profiles: $PROFILE"
echo

profiles="$(list_profiles)"
[ -n "$profiles" ] || {
  echo "ERROR: no targets for profile: $PROFILE"
  exit 2
}

for profile in $profiles; do
  echo "Profile: $profile"
  echo "Saved mode: $(mode_for_profile "$profile")"
  for pkg in $(list_packages_for_profile "$profile"); do
    for user in $USERS; do
      check_user_profile_pkg "$user" "$profile" "$pkg"
    done
    check_running_services_for_profile_pkg "$profile" "$pkg"
  done
  echo
done
