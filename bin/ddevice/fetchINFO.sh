baserom="$1"
work_dir=$(pwd)
source $work_dir/functions.sh

IMG_ROOT="$work_dir/build/baserom/images"

find_prop_file() {
    local key="$1"; shift
    local f
    for f in "$@"; do
        [ -f "$f" ] && grep -q "^${key}=" "$f" 2>/dev/null && { echo "$f"; return 0; }
    done
    return 1
}

# Prefer specific partition build.prop files, but also search broadly (layout differs by ROM)
find_system_build_prop() {
    local cands=(
        "$IMG_ROOT/system/system/build.prop"
        "$IMG_ROOT/system/build.prop"
        "$IMG_ROOT/system_ext/etc/build.prop"
        "$IMG_ROOT/system_ext/build.prop"
        "$IMG_ROOT/product/etc/build.prop"
        "$IMG_ROOT/product/build.prop"
        "$IMG_ROOT/vendor/build.prop"
        "$IMG_ROOT/vendor/etc/build.prop"
        "$IMG_ROOT/odm/etc/build.prop"
        "$IMG_ROOT/odm/build.prop"
    )
    local f
    for f in "${cands[@]}"; do
        [ -f "$f" ] && { echo "$f"; return 0; }
    done
    f=$(find "$IMG_ROOT" -type f -name build.prop 2>/dev/null | head -n 1)
    [ -n "$f" ] && { echo "$f"; return 0; }
    return 1
}

get_prop_key() {
    local key="$1" file="$2"
    [ -f "$file" ] || return 0
    grep -m1 "^${key}=" "$file" 2>/dev/null | cut -d'=' -f2- | tr -d '\r\n'
}

regionTYPE=$(cat $work_dir/bin/ddevice/device_type.txt 2>/dev/null | tr -d '\r\n')
SYS_PROP=$(find_system_build_prop || true)

AndroidVer=""
sdkLevel=""
if [ -n "$SYS_PROP" ]; then
    AndroidVer=$(get_prop_key "ro.system.build.version.release" "$SYS_PROP")
    [ -z "$AndroidVer" ] && AndroidVer=$(get_prop_key "ro.build.version.release" "$SYS_PROP")
    sdkLevel=$(get_prop_key "ro.system.build.version.sdk" "$SYS_PROP")
    [ -z "$sdkLevel" ] && sdkLevel=$(get_prop_key "ro.build.version.sdk" "$SYS_PROP")
fi
# Fallback: scan any build.prop for version info
if [ -z "$AndroidVer" ] || [ -z "$sdkLevel" ]; then
    while IFS= read -r f; do
        [ -z "$AndroidVer" ] && AndroidVer=$(get_prop_key "ro.build.version.release" "$f")
        [ -z "$sdkLevel" ] && sdkLevel=$(get_prop_key "ro.build.version.sdk" "$f")
        [ -n "$AndroidVer" ] && [ -n "$sdkLevel" ] && break
    done < <(find "$IMG_ROOT" -type f -name build.prop 2>/dev/null)
fi
[ -z "$AndroidVer" ] && AndroidVer="15"
[ -z "$sdkLevel" ] && sdkLevel="35"
device_code=$(cat $work_dir/bin/ddevice/device_code.txt 2>/dev/null | tr -d '\r\n')
[ -z "$device_code" ] && device_code=$(cat $work_dir/bin/ddevice/device_f.txt 2>/dev/null | tr -d '\r\n')
[ -z "$device_code" ] && device_code="YourDevice"

name=$(cat $work_dir/bin/ddevice/device_name.txt 2>/dev/null | tr -d '\r\n')
[ -z "$name" ] && name=$(cat $work_dir/bin/ddevice/name_devices.txt 2>/dev/null | tr -d '\r\n')
[ -z "$name" ] && name="Xiaomi Device"
base_rom_code=$(cat $work_dir/bin/ddevice/base_rom_code.txt)
rom_os=$(cat $work_dir/bin/ddevice/rom_os.txt)
starxVER=$(cat $work_dir/Version)
systemtype=$(cat $work_dir/bin/ddevice/fstype.txt)

AB_PROP=""
for c in "$IMG_ROOT/vendor/build.prop" "$IMG_ROOT/vendor/etc/build.prop" "$IMG_ROOT/system/system/build.prop" "$IMG_ROOT/system/build.prop"; do
    [ -f "$c" ] && AB_PROP="$c" && break
done
if [ -n "$AB_PROP" ] && grep -q "ro.build.ab_update=true" "$AB_PROP" 2>/dev/null; then
    echo "VAB" > $work_dir/bin/script2flash/META-INF/Data/Structure
elif [ "$(cat $work_dir/bin/ddevice/romtype.txt 2>/dev/null | tr -d '\r\n')" = "payload" ]; then
    echo "VAB" > $work_dir/bin/script2flash/META-INF/Data/Structure
else
    echo "Non-VAB" > $work_dir/bin/script2flash/META-INF/Data/Structure
fi

# Chip: quyết định zip có flash được bằng recovery hay không (update-binary chặn
# MediaTek). Bản cũ chỉ dò init.qcom.rc - thiếu file đó là ghi "Mediatek" và
# update-binary từ chối cài trên máy Snapdragon.
#
# Giờ ưu tiên build.prop, vì ro.board.platform / ro.hardware là thứ ROM luôn có.
# Xiaomi chỉ dùng 2 nền: qcom (Snapdragon) và mtk (MediaTek), nên chỉ cần tìm
# dấu hiệu mtk; không thấy thì là Snapdragon. Kernel MTK luôn để lại "mtk" trong
# ro.board.platform / ro.hardware.
vendor_prop="$IMG_ROOT/vendor/build.prop"
[ ! -f "$vendor_prop" ] && vendor_prop="$IMG_ROOT/vendor/etc/build.prop"
board=$(grep -m1 -E '^(ro\.board\.platform|ro\.hardware)=' "$vendor_prop" 2>/dev/null | cut -d= -f2 | tr -d '\r\n ')
board_lc=$(printf '%s' "$board" | tr 'A-Z' 'a-z')

if [ -z "$board_lc" ]; then
    while IFS= read -r f; do
        board=$(grep -m1 -E '^(ro\.board\.platform|ro\.hardware)=' "$f" 2>/dev/null | cut -d= -f2 | tr -d '\r\n ')
        [ -n "$board" ] && break
    done < <(find "$IMG_ROOT" -type f -name build.prop 2>/dev/null)
    board_lc=$(printf '%s' "$board" | tr 'A-Z' 'a-z')
fi

if [ -z "$board_lc" ]; then
    if [ -f "$IMG_ROOT/vendor/etc/init/hw/init.qcom.rc" ] || [ -f "$IMG_ROOT/vendor/etc/init/init.qcom.rc" ]; then
        board_lc="qcom"
    else
        board_lc="mtk"
    fi
fi
case "$board_lc" in
    *mtk*|*mediatek*) echo "Mediatek"   > $work_dir/bin/script2flash/META-INF/Data/Chip ;;
    *)                echo "Snapdragon" > $work_dir/bin/script2flash/META-INF/Data/Chip ;;
esac
echo "Chip platform: ${board:-$board_lc} -> $(cat $work_dir/bin/script2flash/META-INF/Data/Chip)"

echo "$os_type" > $work_dir/bin/ddevice/os_type.txt
echo "$AndroidVer" > $work_dir/bin/ddevice/androidver.txt
echo "$sdkLevel" > $work_dir/bin/ddevice/sdkLevel.txt
#Parse Data
echo "$AndroidVer" > $work_dir/bin/script2flash/META-INF/Data/AndroidVer
echo "$base_rom_code" > $work_dir/bin/script2flash/META-INF/Data/RomBased
echo "$starxVER" > $work_dir/bin/script2flash/META-INF/Data/Version
echo "$regionTYPE" > $work_dir/bin/script2flash/META-INF/Data/Region
echo "$name" > $work_dir/bin/script2flash/META-INF/Data/DeviceName
echo "$systemtype" > $work_dir/bin/script2flash/META-INF/Data/Types


echo "------------------ Error OS BuildInfo ---------------------"
echo "- Device Name: $name"
echo "- Codename: $device_code"
echo "- Xiaomi Version: $rom_os"  
echo "- BuildRegion: $regionTYPE"
echo "- Android: $AndroidVer"                                      
echo "- Base ROM Code: $base_rom_code"                                                                        
echo "- BuildTool Version: $starxVER"
echo "- OS Type: $systemtype"
echo "--------------------------------------------------------"
