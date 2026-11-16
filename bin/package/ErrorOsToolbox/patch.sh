#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# ---------------------------------------------------------------------------
# Error OS Toolbox - package hệ thống nội bộ, giao diện cho Cài đặt -> Toolbox.
#
# Khác RootToolbox (bản cũ):
#   - APK include sẵn sukisu_ultra.apk + module ZygiskNext+AlwaysStrongInject.zip.
#   - Không có launcher icon; chỉ mở được qua Cài đặt -> Toolbox
#     (settings_headers.xml do patch_settings_mod.py nhúng vào Settings.apk).
#   - Row SukiSU Ultra: mở manager nếu đã cài, chưa cài thì mở trình cài
#     đặt (xác nhận 1 lần) - đúng luồng Root Toolbox trước đây.
#   - Row Flash Module: chạy su + customize.sh của bundle (zygisksu + tricky_store).
#   - Row Kaorios: mở com.kousei.kaorios (install KaoriosToolbox vào product/app,
#     xem bin/package/KaoriosToolbox/patch.sh - chạy khi erroros_toolbox=true).
#
# Settings trỏ tới com.erroros.toolbox/.MainActivity, do patch_settings_mod.py
# đọc toolbox_target_package|class từ config.env.
# ---------------------------------------------------------------------------

work_dir=$(pwd)
source "$work_dir/functions.sh"

ENABLE=$(grep -m1 '^erroros_toolbox=' "$work_dir/config.env" 2>/dev/null | cut -d= -f2 | tr -d ' \r\n')
if [ "$ENABLE" != "true" ]; then
    mods "ErrorOsToolbox: bỏ qua (erroros_toolbox=$ENABLE)"
    exit 0
fi

SRC="$work_dir/bin/package/ErrorOsToolbox/ErrorOsToolbox.apk"
IMG="$work_dir/build/baserom/images"

if [ ! -f "$SRC" ]; then
    warn "ErrorOsToolbox: chưa có $SRC - bỏ qua"
    exit 0
fi

if [ ! -d "$IMG/product" ]; then
    warn "ErrorOsToolbox: không thấy product/ - bỏ qua"
    exit 0
fi

APP_DIR="$IMG/product/app/ErrorOsToolbox"
mkdir -p "$APP_DIR" || { warn "ErrorOsToolbox: tạo thư mục thất bại"; exit 0; }

cp -f "$SRC" "$APP_DIR/ErrorOsToolbox.apk" || { warn "ErrorOsToolbox: copy APK thất bại"; exit 0; }
chmod 0644 "$APP_DIR/ErrorOsToolbox.apk"

FS_CFG="$IMG/config/product_fs_config"
if [ -f "$FS_CFG" ]; then
    {
        echo "product/app/ErrorOsToolbox 0 0 0755"
        echo "product/app/ErrorOsToolbox/ErrorOsToolbox.apk 0 0 0644"
    } >> "$FS_CFG"
fi

mods "ErrorOsToolbox: cài đặt -> product/app/ErrorOsToolbox ($(stat -c%s "$SRC") byte, chỉ qua Cài đặt -> Toolbox)"
exit 0
