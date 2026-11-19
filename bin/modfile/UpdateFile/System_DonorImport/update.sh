#!/bin/bash
# ErrorOS - Donor Import (opt-in, whitelist-based)
# Safely copy selected assets/configs from a donor ROM extracted images tree
# into the current build images. Default OFF. Use explicit allowlist paths only.
#
# Goals: let users pull "nice-to-have" things (themes/media/cust/overlays/permissions)
# from a compatible donor (e.g. PureCN same device/base) without blind porting.
# Non-goals: boot/vendor/firmware/framework core patching, notification/GPS/power hacks.
#
# Config (config.env):
#   donor_import_enable=true|false
#   donor_source_dir=<path to extracted images root, absolute or relative to work_dir>
#   donor_allowlist_file=<optional path to allowlist file; default: this module's allowlist.txt>
#
# Allowlist format: one relative path per line under donor_source_dir/images layout
# (e.g. mi_ext/product/media/theme, mi_ext/product/etc/precust_theme). Comments (#) and
# blank lines ignored. Paths are copied with cp -a into build/baserom/images/<path>.

work_dir=$(pwd)
source "$work_dir/functions.sh"

ENABLE=$(grep -m1 '^donor_import_enable=' "$work_dir/config.env" 2>/dev/null | cut -d= -f2 | tr -d '\r\n ')
SRC_DIR_CFG=$(grep -m1 '^donor_source_dir=' "$work_dir/config.env" 2>/dev/null | cut -d= -f2- | tr -d '\r\n')
ALLOWLIST_CFG=$(grep -m1 '^donor_allowlist_file=' "$work_dir/config.env" 2>/dev/null | cut -d= -f2- | tr -d '\r\n')

[ -z "$ENABLE" ] && ENABLE=false
if [ "$ENABLE" != "true" ]; then
    mods "DonorImport: skipped (donor_import_enable!=true)"
    exit 0
fi

MAIN_FOLDER="$work_dir/build/baserom/images"
MODULE_DIR="$work_dir/bin/modfile/UpdateFile/System_DonorImport"
ALLOWLIST="$ALLOWLIST_CFG"
[ -z "$ALLOWLIST" ] && ALLOWLIST="$MODULE_DIR/allowlist.txt"
case "$ALLOWLIST" in /*) ;; *) ALLOWLIST="$work_dir/$ALLOWLIST" ;; esac

SRC="$SRC_DIR_CFG"
case "$SRC" in /*) ;; *) [ -n "$SRC" ] && SRC="$work_dir/$SRC" ;; esac

if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
    warn "DonorImport: donor_source_dir missing/invalid: '$SRC_DIR_CFG'"
    exit 0
fi
if [ ! -f "$ALLOWLIST" ]; then
    warn "DonorImport: allowlist not found: $ALLOWLIST"
    exit 0
fi
if [ ! -d "$MAIN_FOLDER" ]; then
    warn "DonorImport: build images folder not found"
    exit 0
fi

copied=0
skipped=0
while IFS= read -r line || [ -n "$line" ]; do
    # strip CR and comments
    line=$(printf '%s' "$line" | tr -d '\r')
    line="${line%%#*}"
    # trim leading/trailing spaces
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$line" ] && continue

    # basic safety: disallow absolute paths and parent traversal
    case "$line" in
        /*|*../*|../*|..)
            warn "DonorImport: unsafe path skipped: $line"
            skipped=$((skipped+1))
            continue
            ;;
    esac

    src_path="$SRC/$line"
    dst_path="$MAIN_FOLDER/$line"

    if [ ! -e "$src_path" ]; then
        warn "DonorImport: not found in donor: $line"
        skipped=$((skipped+1))
        continue
    fi

    mkdir -p "$(dirname "$dst_path")"
    if cp -a "$src_path" "$dst_path" 2>/dev/null; then
        mods "DonorImport: copied $line"
        copied=$((copied+1))
    else
        warn "DonorImport: copy failed: $line"
        skipped=$((skipped+1))
    fi
done < "$ALLOWLIST"

mods "DonorImport: done (copied=$copied skipped=$skipped)"
mods "DonorImport: verify boot/notifications/GPS after flash; use only compatible donor assets"
