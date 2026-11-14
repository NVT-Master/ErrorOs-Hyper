#!/bin/bash
# ---------------------------------------------------------------------------
# Error OS - PowerTune: tinh chỉnh pin hợp lý + không lag
#
#   ro.vendor.qti.sys.fw.bg_apps_limit - giới hạn số app nền MIUI quản lý.
#     Mặc định của MIUI thường là 32; đặt 12 giúp máy bớt lag và bớt thức đêm
#     (sync ngầm, watchjob) thừa. Có thể đổi trong config.env:
#       power_tune_bglimit=<số>   (0 = bỏ qua, không ghi prop)
#
#   Thông báo KHÔNG bị miss: FCM fix trong pipeline (NOTIFICATION_FIX/A17 +
#   System_FCMBootApply) đã đảm bảo GMS không bị đóng băng -> push tới được app.
# ---------------------------------------------------------------------------
work_dir=$(pwd)
source "$work_dir/functions.sh"
MAIN_FOLDER="$work_dir/build/baserom/images"

LIMIT=$(grep -m1 '^power_tune_bglimit=' "$work_dir/config.env" 2>/dev/null | cut -d= -f2 | tr -d '\r\n ')
[ -z "$LIMIT" ] && LIMIT=12

if [ "$LIMIT" = "0" ]; then
    mods "PowerTune: power_tune_bglimit=0 - bỏ qua"
    exit 0
fi

for prop in "$MAIN_FOLDER/system/build.prop" "$MAIN_FOLDER/system/system/build.prop" "$MAIN_FOLDER/product/etc/build.prop"; do
    [ -f "$prop" ] || continue
    sed -i -e '/^ro\.vendor\.qti\.sys\.fw\.bg_apps_limit=/d' "$prop"
    [ -n "$(tail -c1 "$prop")" ] && echo "" >> "$prop"
    echo "ro.vendor.qti.sys.fw.bg_apps_limit=$LIMIT" >> "$prop"
    mods "PowerTune: bg_apps_limit=$LIMIT -> ${prop#$MAIN_FOLDER/}"
done
