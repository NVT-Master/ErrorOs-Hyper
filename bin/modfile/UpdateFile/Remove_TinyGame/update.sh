#!/bin/bash
# ---------------------------------------------------------------------------
# Debloat (user-approved removals only).
# Removes ONLY com.xiaomi.tinygame - Xiaomi's mini-games hub ("Spotlight").
# Pure ad-driven mini games + background ads; serves no System function.
# Explicitly approved by the ROM owner (2026-11-16): "app tiểu game vô dụng bỏ đi".
# Any other removals go through explicit approval - DO NOT expand silently.
# ---------------------------------------------------------------------------
set +e
work_dir=$(pwd)
MAIN_FOLDER="$work_dir/build/baserom/images"
source "$work_dir/functions.sh" 2>/dev/null || true

TARGETS="
product/data-app/TinyGame
system_ext/priv-app/com.xiaomi.tinygame
product/priv-app/com.xiaomi.tinygame
"

removed=0
for t in $TARGETS; do
    d="$MAIN_FOLDER/$t"
    if [ -e "$d" ]; then
        rm -rf "$d"
        mods "Debloat: removed $t"
        removed=$((removed + 1))
    fi
done

if [ "$removed" -eq 0 ]; then
    warn "Debloat: TinyGame not found in images (path layout different?)"
else
    mods "Debloat: TinyGame removal done ($removed target(s))"
fi
exit 0
