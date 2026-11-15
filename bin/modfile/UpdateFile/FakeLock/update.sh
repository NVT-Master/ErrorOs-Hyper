#!/bin/bash
# ---------------------------------------------------------------------------
# FakeLock - spoof verifiedbootstate=green o tang cmdline cua kernel
#
# NothingVN's trick; errorOS dinh kem cho day du spoof.
# KHONG khoa bootloader. KHONG doi vbmeta flags. KHONG co fastboot oem lock o
# bat ky dau. Bootloader van unlocked; fastboot van vao bat ky khi nao.
#
# Yeu cau: vendor_boot v4 + cmdline trong header. Changing vendor_boot header
# chi them "androidboot.verifiedbootstate=green" vao cmdline - hop le voi AVB
# vi vendor_boot KHONG phai partition duoc verify theo cach thong thuong.
# ---------------------------------------------------------------------------
set +e
work_dir=$(pwd)
source "$work_dir/functions.sh"

VENDOR_BOOT="$work_dir/build/baserom/images/vendor_boot.img"
MAGISKBOOT="$work_dir/bin/Linux/x86_64/magiskboot"

if [ ! -f "$VENDOR_BOOT" ]; then
    mods "FakeLock: khong co vendor_boot.img - bo qua"
    exit 0
fi
if [ ! -x "$MAGISKBOOT" ]; then
    mods "FakeLock: thieu magiskboot - bo qua"
    exit 0
fi

TMPD=$(mktemp -d /tmp/fakelock.XXXXXX)
trap 'rm -rf "$TMPD"' EXIT
cp -f "$VENDOR_BOOT" "$TMPD/vendor_boot.img"

cd "$TMPD" || exit 0
if ! "$MAGISKBOOT" unpack "vendor_boot.img" >/dev/null 2>&1; then
    cd "$work_dir"
    mods "FakeLock: unpack vendor_boot.img FAIL - bo qua (vendor_boot giu nguyen)"
    rm -rf "$TMPD"
    exit 0
fi

if [ ! -f "$TMPD/header" ] || ! grep -q '^cmdline=' "$TMPD/header"; then
    cd "$work_dir"
    mods "FakeLock: header khong co cmdline - bo qua (vendor_boot giu nguyen)"
    rm -rf "$TMPD"
    exit 0
fi

sed -i '/^cmdline=/ s/$/ androidboot.verifiedbootstate=green/' "$TMPD/header"

if ! "$MAGISKBOOT" repack "vendor_boot.img" >/dev/null 2>&1; then
    cd "$work_dir"
    mods "FakeLock: repack vendor_boot.img FAIL - bo qua (vendor_boot giu nguyen)"
    rm -rf "$TMPD"
    exit 0
fi

if [ -f "$TMPD/new-boot.img" ]; then
    cp -f "$TMPD/new-boot.img" "$VENDOR_BOOT"
    cd "$work_dir"
    rm -rf "$TMPD"
    mods "FakeLock: vendor_boot cmdline += verifiedbootstate=green (khong khoa BL)"
else
    cd "$work_dir"
    rm -rf "$TMPD"
    mods "FakeLock: new-boot.img khong xuat hien - vendor_boot giu nguyen"
fi
exit 0
