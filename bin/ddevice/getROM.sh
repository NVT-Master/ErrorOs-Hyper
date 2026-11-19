#!/bin/bash

baserom="$1"
work_dir=$(pwd)
source $work_dir/functions.sh

# Check whether it is a local package or a link
if [ ! -f "${baserom}" ] && [ "$(echo $baserom |grep http)" != "" ]; then
    info "Download link detected, starting a download..."

    # Kiem tra file tai ve co dung la mot zip hoan chinh khong.
    # unzip -t (Info-ZIP) FAIL VOI ZIP SIGNED/APK LON (~8 GB) - download OK nhung
    # -t bao loi -> build sai "file hong". Dung listing (unzip -l / 7z l) nhu
    # buoc runtime cua build.sh dung, thua du kiem central directory.
    rom_zip_ok() {
        [ -f "$1" ] || return 1
        unzip -l "$1" >/dev/null 2>&1 && return 0
        if command -v 7z >/dev/null 2>&1; then
            7z l "$1" >/dev/null 2>&1
            return $?
        fi
        return 1
    }

    # Resolve actual downloaded file path. Some URLs (proxies/obfuscated) return the
    # real filename via Content-Disposition, so aria2c may save to a different name
    # than the URL basename we guessed.
    rom_resolve_downloaded() {
        local requested="$1" candidate
        if rom_zip_ok "$requested"; then
            echo "$requested"
            return 0
        fi
        # If requested name exists but is not a valid zip, also consider other zips
        # (aria2c may have completed content-disposition file while requested is stale).
        for candidate in "$requested" *.zip; do
            [ -f "$candidate" ] || continue
            rom_zip_ok "$candidate" && { echo "$candidate"; return 0; }
        done
        # Fallback: newest zip in cwd (best effort)
        candidate=$(ls -1t *.zip 2>/dev/null | head -n 1 || true)
        if [ -n "$candidate" ] && [ -f "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
        return 1
    }

    rom_sha256_ok() {
        local file="$1" expected="$2" actual
        [ -z "$expected" ] && return 0
        expected=$(echo "$expected" | tr 'A-F' 'a-f' | tr -d ' \r\n\t')
        if ! command -v sha256sum >/dev/null 2>&1; then
            warn "ROM: sha256sum khong kha dung, bo qua kiem tra SHA256"
            return 0
        fi
        actual=$(sha256sum "$file" 2>/dev/null | awk '{print $1}' | tr 'A-F' 'a-f')
        if [ -z "$actual" ]; then
            warn "ROM: khong tinh duoc SHA256 cho $file"
            return 1
        fi
        if [ "$actual" = "$expected" ]; then
            info "ROM: SHA256 hop le"
            return 0
        fi
        warn "ROM: SHA256 sai (expected=$expected actual=$actual)"
        return 1
    }

    download_rom_url() {
        local url="$1" target="$2" attempt resolved
        for attempt in 1 2 3; do
            # Lan 1: -c de resume neu con file do dang. Cac lan sau: file da bi
            # nghiem la hong (khong chi thieu byte) nen phai xoa va tai lai tu dau,
            # vi resume tu mot central directory hong se ket thuc ngay lap tuc.
            if [ "$attempt" -gt 1 ]; then
                rm -f "$target"
                # If previous attempt saved under a different (content-disposition) name
                # and it was invalid, remove it so retries don't reuse a bad file.
                resolved=$(rom_resolve_downloaded "$target" 2>/dev/null || true)
                if [ -n "$resolved" ] && [ "$resolved" != "$target" ]; then
                    rm -f "$resolved" "${resolved}.aria2" 2>/dev/null || true
                fi
            fi

            # -c: resume.
            # --timeout/--connect-timeout/--max-tries: mac dinh aria2 khong co gioi
            #     han tong, gap CDN tra cham la treo im lang khong bao gio ket thuc.
            # --lowest-speed-limit: 10K chi bat dung truong hop chet han, --timeout=60
            #     bat stall that su (CDN Xiaomi co luc cham nhung van tai duoc).
            # --summary-interval=10: in tien do moi 10s de log CI thay no con chay.
            aria2c -c --max-tries=20 --retry-wait=5 \
                --timeout=60 --connect-timeout=30 --lowest-speed-limit=10K \
                --summary-interval=10 --console-log-level=warn \
                --max-download-limit=1024M --file-allocation=none -s10 -x10 -j10 \
                --content-disposition -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                "${url}" || true

            resolved=$(rom_resolve_downloaded "$target" 2>/dev/null || true)
            if [ -n "$resolved" ] && rom_zip_ok "$resolved" && rom_sha256_ok "$resolved" "$rom_sha256_expected"; then
                ROM_DOWNLOADED_FILE="$resolved"
                return 0
            fi
            warn "ROM: lan tai $attempt tu $url chua hop le - thu lai"
        done
        return 1
    }

    # Ten file tren dia khac URL: --content-disposition lay ten tu header.
    # Phai tinh TRUOC vong lap, vi vong lap can biet dang kiem file nao.
    rom_file=$(basename "${baserom%%\?*}")
    rom_mirrors_raw="${ROM_MIRROR_URLS:-}"
    rom_sha256_expected="${ROM_SHA256:-}"
    ROM_DOWNLOADED_FILE=""
    if [ -n "$rom_mirrors_raw" ]; then
        info "ROM: mirrors bo sung da cau hinh (ROM_MIRROR_URLS)"
    fi
    if [ -n "$rom_sha256_expected" ]; then
        info "ROM: se kiem tra SHA256 sau khi tai"
    fi
    info "ROM: file dich ${rom_file}"

    rom_downloaded=0
    # Thu URL chinh truoc
    if download_rom_url "${baserom}" "$rom_file"; then
        rom_downloaded=1
    fi

    # Neu that bai va co mirrors, thu lan luot mirrors (giu ten file dich de phu hop pipeline)
    if [ "$rom_downloaded" -ne 1 ] && [ -n "$rom_mirrors_raw" ]; then
        old_ifs="$IFS"
        IFS=', '
        for mirror in $rom_mirrors_raw; do
            IFS="$old_ifs"
            [ -z "$mirror" ] && continue
            warn "ROM: thu mirror: $mirror"
            rm -f "$rom_file" *.aria2 2>/dev/null || true
            if download_rom_url "$mirror" "$rom_file"; then
                rom_downloaded=1
                info "ROM: tai thanh cong tu mirror"
                break
            fi
        done
        IFS="$old_ifs"
    fi

    baserom="$rom_file"
    if [ -n "$ROM_DOWNLOADED_FILE" ] && [ -f "$ROM_DOWNLOADED_FILE" ]; then
        baserom="$ROM_DOWNLOADED_FILE"
        if [ "$baserom" != "$rom_file" ]; then
            info "ROM: da nhan file tu server: $baserom"
        fi
    elif [ -f $work_dir/topaz-ota_full-OS3.0.2.0.WMGCNXM-user-16.0-b487e82659.zip ]; then
        baserom="topaz-ota_full-OS3.0.2.0.WMGCNXM-user-16.0-b487e82659.zip"
        info "BASEROM: ${baserom}"
    elif [ -f $work_dir/munch-ota_full-OS2.0.215.0.VLMCNXM-user-15.0-7df6d5ee94.zip ]; then
        baserom="munch-ota_full-OS2.0.215.0.VLMCNXM-user-15.0-7df6d5ee94.zip"
        info "BASEROM: ${baserom}"
    fi

    if [ "$rom_downloaded" -ne 1 ] || ! rom_zip_ok "${baserom}"; then
        error "Download error! (thieu, hong hoac sai checksum: ${baserom})"
        exit 1
    fi
elif [ -f "${baserom}" ]; then
    info "BASEROM: ${baserom}"
else
    error "BASEROM: Invalid parameter"
    exit 1
fi


# Get ROM Info
if [ "$(echo $baserom |grep miui_)" != "" ]; then
    device_code=$(basename $baserom |cut -d '_' -f 2)
    base_rom_code=$(echo "$baserom" | awk -F'_' '{print $3}')
elif [ "$(echo $baserom |grep xiaomi.eu_)" != "" ]; then
    device_code=$(basename $baserom |cut -d '_' -f 3)
    base_rom_code=$(echo "$baserom" | awk -F'_' '{print $3}')
elif [ "$(echo $baserom | grep -E '.*-ota_full-.*')" != "" ]; then
    device_code=$(basename $baserom | cut -d '-' -f 1)
    base_rom_code=$(basename $baserom | cut -d '-' -f 3)

    # Transform device_code
    device_code=$(echo $device_code | awk -F '_' '{
        if (NF == 1) {
            # If one part, e.g., shennong
            print toupper($1)
        } else if (NF == 2) {
            # If two parts, e.g., tapas_global
            print toupper($1) toupper(substr($2, 1, 1)) substr($2, 2)
        } else if (NF == 3) {
            # If three parts, e.g., houji_tw_global
            printf toupper($1) toupper($2) toupper(substr($3, 1, 1)) substr($3, 2)
        }
    }')
else
    device_code="YourDevice"
    base_rom_code="Unknown"
fi

device_f=$(echo $device_code | sed 's/\(Global\|EEAGlobal\|INGlobal\|IDGlobal\|RUGlobal\|TWGlobal\|TRGlobal\|JPGlobal\)$//' | tr '[:upper:]' '[:lower:]')

# Determine Device Type
info "Get Device Type"
if echo "$device_code" | grep -q 'EEAGlobal'; then
    DEVICE_TYPE="EEAGlobal"
elif echo "$device_code" | grep -q 'INGlobal'; then
    DEVICE_TYPE="INGlobal"
elif echo "$device_code" | grep -q 'IDGlobal'; then
    DEVICE_TYPE="IDGlobal"
elif echo "$device_code" | grep -q 'RUGlobal'; then
    DEVICE_TYPE="RUGlobal"
elif echo "$device_code" | grep -q 'JPGlobal'; then
    DEVICE_TYPE="JPGlobal"
elif echo "$device_code" | grep -q 'TWGlobal'; then
    DEVICE_TYPE="TWGlobal"
elif echo "$device_code" | grep -q 'TRGlobal'; then
    DEVICE_TYPE="TRGlobal"
elif echo "$device_code" | grep -q 'Global'; then
    DEVICE_TYPE="Global"
else
    DEVICE_TYPE="China"
fi

#Check MIUI or Hyper
if echo "$base_rom_code" | grep -q "OS1"; then
    ROM_OS="OS1"
elif echo "$base_rom_code" | grep -q "OS2"; then
    ROM_OS="OS2"
elif echo "$base_rom_code" | grep -q "OS3"; then
    ROM_OS="OS3"
elif echo "$base_rom_code" | grep -q "OS4"; then
    ROM_OS="OS4"
elif echo "$base_rom_code" | grep -qE "OS[0-9]+"; then
    ROM_OS=$(echo "$base_rom_code" | grep -oE "OS[0-9]+" | head -n 1)
elif echo "$base_rom_code" | grep -q "V14"; then
    ROM_OS="MIUI"
elif echo "$base_rom_code" | grep -q "V13"; then
    ROM_OS="MIUI"
else
    echo "Unsupport ROM Exiting..."
    exit 1
fi

echo $base_rom_code > $work_dir/bin/ddevice/base_rom_code.txt
echo $base_rom_code > $work_dir/bin/ddevice/os_code.txt
echo $device_code > $work_dir/bin/ddevice/device_code.txt
echo $DEVICE_TYPE > $work_dir/bin/ddevice/device_type.txt
echo $ROM_OS > $work_dir/bin/ddevice/rom_os.txt
