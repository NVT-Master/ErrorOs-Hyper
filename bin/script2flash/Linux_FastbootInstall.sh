#!/bin/bash
echo "Chao mung den voi Error OS Flash Tool"
cd "$(dirname "$0")" || exit 1

FASTBOOT="fastboot"

if ! command -v $FASTBOOT >/dev/null 2>&1; then
    if [ -x "META-INF/bin/fastboot" ]; then
        FASTBOOT="META-INF/bin/fastboot"
    else
        echo "Khong tim thay fastboot. Dang cai dat android-tools..."
        sudo pacman -S --noconfirm --needed android-tools
        if command -v fastboot >/dev/null 2>&1; then
            FASTBOOT="fastboot"
        else
            echo "Cài fastboot thất bại (sudo pacman -S android-tools)."
            read -r -p "Nhấn Enter để thoát..."
            exit 1
        fi
    fi
fi

DeviceCodeRom=$(cat META-INF/Data/DeviceCode 2>/dev/null | tr -d '\r\n')

echo ""
echo "[i] - Doc thong tin truoc khi flash"
echo ""
echo "1. ROM nay can bootloader da unlock! Neu chua, vui long dong cua so nay lai."
echo "2. Flash ROM se MAT TOAN BO DU LIEU! Kiem tra ky truoc khi bam."
echo "3. Day la ROM FREE! Neu ban thay ai ban ROM nay, hay bao admin ngay."
echo "4. Chung toi KHONG chiu trach nhiem neu may ban bi loi/brick sau khi flash."
echo "5. Bam dung ROM cua may ban - sai se brick."
echo ""
echo "[i] - Neu ban da hieu, nhan Enter de bat dau. Hoac dong cua so nay."
read -r -p ""

echo "========================================================================================="
echo " Chon che do format truoc khi flash"
echo ""
echo "   y = Format toan bo Data (Flash sach - mat het du lieu)         "
echo "   n = Giu du lieu (Dirty flash - khong mat du lieu)"
echo ""
echo "========================================================================================="
read -r -p "Lua chon cua ban {y/n}: " CHOICE
echo "========================================================================================="
echo "Ket noi dien thoai vao PC + boot vao Fastboot mode"
echo "Neu khong nhan thay may - bam nut tang/giam am luong de fastboot reload"
echo "Va cai lai driver"
echo "========================================================================================="

DeviceCodeReal=$($FASTBOOT getvar product 2>&1 | grep -i "product:" | awk '{print $2}' | tr -d '\r\n')
fqlx=$($FASTBOOT getvar slot-count 2>&1 | grep -i "slot-count:" | awk '{print $2}' | tr -d '\r\n')

if [ "$fqlx" = "2" ]; then
    fqlx="AB"
else
    fqlx="A"
fi

if [ "$DeviceCodeReal" = "mars" ]; then
    DeviceCodeReal="star"
fi

if [[ "$DeviceCodeReal" != *"$DeviceCodeRom"* ]]; then
    echo "LOI: May dich khac muc ROM nay!"
    echo "May ban la \"$DeviceCodeReal\".  ROM nay cho \"$DeviceCodeRom\"."
    read -r -p "Nhan Enter de thoat..."
    exit 1
fi

for f in *.img.zst; do
    [ -e "$f" ] || continue
    par="${f%.img.zst}"
    rm -f "${par}.img" 2>/dev/null
    echo "  Dang giai nen ${par} ..."
    if command -v zstd >/dev/null 2>&1; then
        zstd -d "$f" -o "${par}.img"
    else
        echo "Khong thay zstd. Dang cai ..."
        sudo pacman -S --noconfirm --needed zstd
        if command -v zstd >/dev/null 2>&1; then
            zstd -d "$f" -o "${par}.img"
        else
            echo "Khong the cai zstd."
            exit 1
        fi
    fi
done

if [ -d "images" ]; then
    for f in images/*; do
        [ -e "$f" ] || continue
        filename=$(basename "$f")
        par="${filename%.*}"
        url="$f"

        if [ "$par" = "cust" ]; then
            $FASTBOOT flash "$par" "$url" >/dev/null 2>&1
        elif [ "$par" = "preloader_raw" ]; then
            $FASTBOOT flash preloader_a "$url" >/dev/null 2>&1
            $FASTBOOT flash preloader_b "$url" >/dev/null 2>&1
            $FASTBOOT flash preloader1 "$url" >/dev/null 2>&1
            $FASTBOOT flash preloader2 "$url" >/dev/null 2>&1
        elif [[ "$par" == vbmeta* ]]; then
            if [ "$fqlx" = "AB" ]; then
                $FASTBOOT --disable-verity --disable-verification flash "${par}_a" "$url"
                $FASTBOOT --disable-verity --disable-verification flash "${par}_b" "$url"
            else
                $FASTBOOT --disable-verity --disable-verification flash "$par" "$url"
            fi
        elif [ "$fqlx" = "AB" ]; then
            $FASTBOOT flash "${par}_a" "$url"
            $FASTBOOT flash "${par}_b" "$url"
        else
            $FASTBOOT flash "$par" "$url"
        fi
    done
fi

if [ -f "super.img" ]; then
    $FASTBOOT flash super super.img
    rm -f super.img 2>/dev/null
fi

if [ "$CHOICE" = "y" ] || [ "$CHOICE" = "Y" ]; then
    echo "  Dang format toan bo Data... (5-10 phut, may se dung hoai)"
    $FASTBOOT erase frp >/dev/null 2>&1
    $FASTBOOT erase userdata >/dev/null 2>&1
    $FASTBOOT erase metadata >/dev/null 2>&1
    echo "  Xong format."
    echo ""
fi

echo "  Done. May se tu khoi dong lai sau giay phut..."
echo "  Lan dau boot co the mat 10-30 phut (toi uu he thong)"
echo "  Dung dung lai may trong qua trinh nay"
echo ""

if [ "$fqlx" = "AB" ]; then
    $FASTBOOT set_active a >/dev/null 2>&1
fi
$FASTBOOT reboot

read -r -p "Nhan Enter de thoat..."
exit 0
