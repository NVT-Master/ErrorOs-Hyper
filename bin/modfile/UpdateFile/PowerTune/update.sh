#!/bin/bash
# ---------------------------------------------------------------------------
# Error OS - PowerTune: tinh chỉnh pin hợp lý + không lag
#
#   ro.vendor.qti.sys.fw.bg_apps_limit - giới hạn số app nền.
#     - Một số ROM/base đọc từ build.prop.
#     - Nhiều máy Qualcomm/HyperOS đọc từ perfconfigstore.xml (perf HAL/vendor),
#       nên cần patch cả XML để có hiệu lực thực tế.
#
#   Cấu hình trong config.env:
#     power_tune_bglimit=<số>   (0 = bỏ qua)
#
#   Thông báo KHÔNG bị miss: FCM fix trong pipeline (NOTIFICATION_FIX/A17 +
#   System_FCMBootApply) đã đảm bảo GMS không bị đóng băng -> push tới được app.
# ---------------------------------------------------------------------------
work_dir=$(pwd)
source "$work_dir/functions.sh"
MAIN_FOLDER="$work_dir/build/baserom/images"

LIMIT=$(grep -m1 '^power_tune_bglimit=' "$work_dir/config.env" 2>/dev/null | cut -d= -f2 | tr -d '\r\n ')
[ -z "$LIMIT" ] && LIMIT=12

case "$LIMIT" in
    ''|*[!0-9]*)
        warn "PowerTune: power_tune_bglimit='$LIMIT' không hợp lệ - bỏ qua"
        exit 0
        ;;
esac

if [ "$LIMIT" = "0" ]; then
    mods "PowerTune: power_tune_bglimit=0 - bỏ qua"
    exit 0
fi

# 1) build.prop (một số base dùng prop trực tiếp)
prop_changed=0
for prop in \
    "$MAIN_FOLDER/system/build.prop" \
    "$MAIN_FOLDER/system/system/build.prop" \
    "$MAIN_FOLDER/product/etc/build.prop" \
    "$MAIN_FOLDER/vendor/build.prop" \
    "$MAIN_FOLDER/odm/etc/build.prop" \
    "$MAIN_FOLDER/system_ext/etc/build.prop"; do
    [ -f "$prop" ] || continue
    sed -i -e '/^ro\.vendor\.qti\.sys\.fw\.bg_apps_limit=/d' "$prop"
    [ -n "$(tail -c1 "$prop")" ] && echo "" >> "$prop"
    echo "ro.vendor.qti.sys.fw.bg_apps_limit=$LIMIT" >> "$prop"
    mods "PowerTune: bg_apps_limit=$LIMIT -> ${prop#$MAIN_FOLDER/}"
    prop_changed=$((prop_changed + 1))
done

# 2) perfconfigstore.xml (perf HAL/vendor, thường là nguồn quyết định thực tế)
xml_changed=0
xml_hits=0
while IFS= read -r -d '' xml; do
    [ -f "$xml" ] || continue
    grep -q 'ro\.vendor\.qti\.sys\.fw\.bg_apps_limit' "$xml" 2>/dev/null || continue
    result=$(python3 - "$xml" "$LIMIT" <<'PY'
import re, sys

path, limit = sys.argv[1], sys.argv[2]
with open(path, 'r', encoding='utf-8', errors='replace', newline='') as f:
    s = f.read()

pat = re.compile(
    r'(<Prop\b[^>]*\bName="ro\.vendor\.qti\.sys\.fw\.bg_apps_limit"[^>]*\bValue=")(\d+)("[^>]*?/?>)'
)
n = 0

def repl(m):
    global n
    if m.group(2) == limit:
        return m.group(0)
    n += 1
    return m.group(1) + limit + m.group(3)

ns = pat.sub(repl, s)
if n:
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(ns)
print(n)
PY
)
    case "$result" in
        ''|*[!0-9]*) result=0 ;;
    esac
    if [ "$result" -gt 0 ]; then
        xml_changed=$((xml_changed + 1))
        xml_hits=$((xml_hits + result))
        mods "PowerTune: bg_apps_limit=$LIMIT -> ${xml#$MAIN_FOLDER/} ($result entry)"
    else
        mods "PowerTune: bg_apps_limit đã là $LIMIT (hoặc không thay đổi) -> ${xml#$MAIN_FOLDER/}"
    fi
done < <(find "$MAIN_FOLDER" -type f -name 'perfconfigstore.xml' -print0 2>/dev/null)

if [ "$prop_changed" -eq 0 ] && [ "$xml_changed" -eq 0 ]; then
    warn "PowerTune: không tìm thấy nơi áp dụng bg_apps_limit trong images (cần kiểm tra thủ công)"
else
    mods "PowerTune: hoàn tất bg_apps_limit=$LIMIT (build.prop=$prop_changed file, perfconfigstore=$xml_changed file / $xml_hits entry)"
fi
