#!/system/bin/sh

MODDIR="${MODDIR:-${0%/*}/..}"
PKG="com.hihonor.systemmanager"
USERS="0 128"
LIST="$MODDIR/common/service-list.txt"
WORK="/data/local/tmp/honor-systemmanager-patch-status"

need_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: $1 not found"
    exit 1
  }
}

check_user_file() {
  user="$1"
  src="/data/system/users/$user/package-restrictions.xml"
  xml="$WORK/package-restrictions-$user.xml"
  blocked=0
  total=0

  echo "User $user:"
  if [ ! -f "$src" ]; then
    echo "  package restrictions missing"
    return
  fi

  abx2xml "$src" "$xml" >/dev/null 2>&1 || {
    echo "  cannot decode package restrictions"
    return
  }

  while IFS= read -r component; do
    [ -n "$component" ] || continue
    total=$((total + 1))
    if sed -n "/<pkg .*name=\"$PKG\"/,/<\\/pkg>/p" "$xml" | grep -q "name=\"$component\""; then
      echo "  blocked: $component"
      blocked=$((blocked + 1))
    else
      echo "  active : $component"
    fi
  done < "$LIST"

  echo "  summary: $blocked/$total blocked"
}

check_running_services() {
  echo "Running target services:"
  found=0
  dump="$(dumpsys activity services "$PKG" 2>/dev/null || true)"
  while IFS= read -r component; do
    [ -n "$component" ] || continue
    short="$component"
    case "$component" in
      com.hihonor.systemmanager.*)
        short=".${component#com.hihonor.systemmanager.}"
        ;;
    esac
    if echo "$dump" | grep -q "$short\\|$component"; then
      echo "  running: $component"
      found=$((found + 1))
    fi
  done < "$LIST"
  [ "$found" -eq 0 ] && echo "  none"
}

need_bin abx2xml
need_bin sed
need_bin grep

mkdir -p "$WORK"
echo "HONOR System Manager Patch status"
echo "Mode: $(cat "$MODDIR/mode" 2>/dev/null || echo unknown)"
echo
for user in $USERS; do
  check_user_file "$user"
done
echo
check_running_services
