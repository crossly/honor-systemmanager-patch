#!/system/bin/sh

MODDIR="${MODDIR:-${0%/*}/..}"
MODE="${1:-}"
PROFILE="${2:-security}"
USERS="0 128"
DATA_ROOT="${DATA_ROOT:-/data}"
WORK_ROOT="${WORK_ROOT:-/data/local/tmp}"
LOG="${LOG_FILE:-$DATA_ROOT/adb/honor-systemmanager-patch.log}"
WORK="$WORK_ROOT/honor-systemmanager-patch"
TARGETS="$MODDIR/common/targets.txt"

log() {
  mkdir -p "${LOG%/*}" 2>/dev/null || true
  echo "[$(date '+%F %T')] $*" >> "$LOG"
}

die() {
  log "ERROR: $*"
  echo "ERROR: $*"
  exit 1
}

need_bin() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found"
}

ensure_tools() {
  need_bin abx2xml
  need_bin xml2abx
  need_bin awk
  need_bin sed
  need_bin grep
  need_bin dd
  need_bin mv
}

make_pkg_list() {
  pkg="$1"
  out="$2"
  awk -F'|' -v pkg="$pkg" -v profiles="$PROFILE" '
    function selected(profile,    n, i, arr) {
      if (profiles == "all") return 1
      n = split(profiles, arr, ",")
      for (i = 1; i <= n; i++) if (arr[i] == profile) return 1
      return 0
    }
    NF >= 3 && $2 == pkg && selected($1) { print $3 }
  ' "$TARGETS" > "$out"
}

list_packages() {
  awk -F'|' -v profiles="$PROFILE" '
    function selected(profile,    n, i, arr) {
      if (profiles == "all") return 1
      n = split(profiles, arr, ",")
      for (i = 1; i <= n; i++) if (arr[i] == profile) return 1
      return 0
    }
    NF >= 3 && selected($1) && !seen[$2]++ { print $2 }
  ' "$TARGETS"
}

patch_xml_block() {
  in_xml="$1"
  out_xml="$2"
  list_file="$3"
  pkg="$4"
  awk -v pkg="$pkg" -v list="$list_file" '
    BEGIN {
      while ((getline line < list) > 0) {
        if (line != "") wanted[line] = 1
      }
      close(list)
      in_pkg = 0
      in_disabled = 0
      pkg_seen = 0
      disabled_seen = 0
    }
    function print_missing(    name) {
      for (name in wanted) {
        if (!(name in existing)) {
          print "      <item name=\"" name "\" />"
        }
      }
    }
    {
      if ($0 ~ "<pkg " && $0 ~ "name=\"" pkg "\"") {
        in_pkg = 1
        pkg_seen = 1
        disabled_seen = 0
        delete existing
      }
      if (in_pkg && $0 ~ "<disabled-components>") {
        in_disabled = 1
        disabled_seen = 1
      }
      if (in_pkg && in_disabled && match($0, /<item name="[^"]+"/)) {
        name = substr($0, RSTART + 12, RLENGTH - 13)
        existing[name] = 1
      }
      if (in_pkg && in_disabled && $0 ~ "</disabled-components>") {
        print_missing()
        in_disabled = 0
      }
      if (in_pkg && !disabled_seen && $0 ~ "</pkg>") {
        print "    <disabled-components>"
        print_missing()
        print "      </disabled-components>"
      }
      print
      if (in_pkg && $0 ~ "</pkg>") {
        in_pkg = 0
      }
    }
    END {
      if (!pkg_seen) exit 42
    }
  ' "$in_xml" > "$out_xml"
}

patch_xml_restore() {
  in_xml="$1"
  out_xml="$2"
  list_file="$3"
  pkg="$4"
  awk -v pkg="$pkg" -v list="$list_file" '
    BEGIN {
      while ((getline line < list) > 0) {
        if (line != "") wanted[line] = 1
      }
      close(list)
      in_pkg = 0
      in_disabled = 0
    }
    {
      if ($0 ~ "<pkg " && $0 ~ "name=\"" pkg "\"") in_pkg = 1
      if (in_pkg && $0 ~ "<disabled-components>") in_disabled = 1
      if (in_pkg && in_disabled && match($0, /<item name="[^"]+"/)) {
        name = substr($0, RSTART + 12, RLENGTH - 13)
        if (name in wanted) next
      }
      print
      if (in_pkg && in_disabled && $0 ~ "</disabled-components>") in_disabled = 0
      if (in_pkg && $0 ~ "</pkg>") in_pkg = 0
    }
  ' "$in_xml" > "$out_xml"
}

process_user() {
  user="$1"
  mode="$2"
  pkg="$3"
  list="$4"
  src="$DATA_ROOT/system/users/$user/package-restrictions.xml"
  [ -f "$src" ] || {
    log "user $user: $src missing, skip"
    return 0
  }

  mkdir -p "$WORK" "$MODDIR/backup"
  orig="$WORK/package-restrictions-$user.orig.abx"
  xml="$WORK/package-restrictions-$user.orig.xml"
  patched_xml="$WORK/package-restrictions-$user.patched.xml"
  patched_abx="$WORK/package-restrictions-$user.patched.abx"
  new_file="$DATA_ROOT/system/users/$user/package-restrictions.xml.new"
  backup="$MODDIR/backup/package-restrictions-$user.before-module.abx"

  dd if="$src" of="$orig" bs=4096 >/dev/null 2>&1 || die "backup read failed for user $user"
  [ -f "$backup" ] || dd if="$src" of="$backup" bs=4096 >/dev/null 2>&1 || die "module backup failed for user $user"

  abx2xml "$orig" "$xml" >/dev/null 2>&1 || die "abx2xml failed for user $user"
  if [ "$mode" = "block" ]; then
    patch_xml_block "$xml" "$patched_xml" "$list" "$pkg" || die "block XML patch failed for user $user pkg $pkg"
  elif [ "$mode" = "restore" ]; then
    patch_xml_restore "$xml" "$patched_xml" "$list" "$pkg" || die "restore XML patch failed for user $user pkg $pkg"
  else
    die "unknown mode: $mode"
  fi
  xml2abx "$patched_xml" "$patched_abx" >/dev/null 2>&1 || die "xml2abx failed for user $user"
  abx2xml "$patched_abx" "$WORK/verify-$user.xml" >/dev/null 2>&1 || die "verify abx failed for user $user"

  rm -f "$new_file"
  dd if="$patched_abx" of="$new_file" bs=4096 >/dev/null 2>&1 || die "write temp failed for user $user"
  chown system:system "$new_file" 2>/dev/null || true
  chmod 0660 "$new_file" 2>/dev/null || true
  chcon u:object_r:system_data_file:s0 "$new_file" 2>/dev/null || true
  mv -f "$new_file" "$src" || die "replace failed for user $user"
  log "user $user pkg $pkg profile=$PROFILE: $mode applied"
}

apply_mode() {
  mode="$1"
  ensure_tools
  [ -f "$TARGETS" ] || die "targets missing: $TARGETS"
  log "mode=$mode profile=$PROFILE start"
  mkdir -p "$WORK"
  packages="$(list_packages)"
  [ -n "$packages" ] || die "no targets for profile: $PROFILE"
  for pkg in $packages; do
    list="$WORK/targets-${PROFILE}-${pkg}.txt"
    make_pkg_list "$pkg" "$list"
    [ -s "$list" ] || continue
    for user in $USERS; do
      process_user "$user" "$mode" "$pkg" "$list"
    done
  done
  log "mode=$mode profile=$PROFILE done"
}

case "$MODE" in
  block|restore)
    apply_mode "$MODE"
    ;;
  *)
    echo "usage: $0 block|restore [security|background|powerkit|all|comma,list]"
    exit 2
    ;;
esac
