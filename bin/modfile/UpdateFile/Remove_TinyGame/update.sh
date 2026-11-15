#!/bin/bash
# ---------------------------------------------------------------------------
# Debloat (USER-APPROVED removals only - do NOT add anything beyond this list).
#
#   product/data-app/TinyGame      com.xiaomi.tinygame  - Xiaomi "Spotlight" mini-games hub (useless, ads)         [user: "vo dung bo di"]
#   product/data-app/MIUIHuanji    com.miui.huanji      - Mi Mover (one-time phone-migration tool, 41MB)          [user: "Xoa luon"]
#   product/data-app/MiuiScanner   com.xiaomi.scanner   - Xiaomi QR/Barcode scanner, Play Store alternatives       [user: "Xoa di"]
#   product/priv-app/MIUIYellowPage com.miui.yellowpage  - Danh ba vang China (ads/spam contacts, 13MB)            [user: "Xoa"]
#   product/app/AnalyticsCore      com.miui.analytics   - Xiaomi telemetry engine core (1.1MB)                     [user: "Xoa"]
#
# User EXPLICITLY wants KEPT (do not touch):
#   MIUISuperMarket (Mi App Store, 63MB) - user: "Giu"
#   com.miui.cleanmaster                 - user: "keep, can clean junk"
#   com.miui.mediaeditor                 - user: "Giu lai"  (217MB, default editor)
#   cn.wps.xiaomi.abroad.lite            - Mi Docs/WPS viewer - user: "mac dinh phai co"
#   com.miui.huanji is Mi Mover - user approved
# ---------------------------------------------------------------------------
set +e
work_dir=$(pwd)
MAIN_FOLDER="$work_dir/build/baserom/images"
source "$work_dir/functions.sh" 2>/dev/null || true

TARGETS="
product/data-app/TinyGame
product/data-app/MIUIHuanji
product/data-app/MiuiScanner
product/priv-app/MIUIYellowPage
product/app/AnalyticsCore
system_ext/priv-app/com.xiaomi.tinygame
product/priv-app/com.xiaomi.tinygame
system_ext/priv-app/MIUIYellowPage
system_ext/app/AnalyticsCore
product/priv-app/MiYellowPage
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
    warn "Debloat: targets not found in images (path layout different?)"
else
    mods "Debloat: removal done ($removed target(s))"
fi
exit 0
