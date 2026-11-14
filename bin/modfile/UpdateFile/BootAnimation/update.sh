#!/bin/bash
# ---------------------------------------------------------------------------
# Error OS - bootanimation + Error OS wallpapers
#
# Ghi de bootanimation.zip cua ROM bang ban Rubik Distressed, va xep 3 hinh
# nen Error OS vao product/media/wallpapers/ (README: wallpaper pickers doc
# thu muc nay). Khong xoa gi cua ROM - chi them/ghi de bang file cua Error OS.
# ---------------------------------------------------------------------------
work_dir=$(pwd)
source "$work_dir/functions.sh"
MAIN_FOLDER="$work_dir/build/baserom/images"
BA_SRC="$work_dir/bin/modfile/UpdateFile/BootAnimation"

if [ ! -f "$BA_SRC/bootanimation.zip" ]; then
    warn "BootAnimation: thiếu $BA_SRC/bootanimation.zip - bỏ qua"
    exit 0
fi

# 1. Boot animation
if [ -d "$MAIN_FOLDER/product/media" ]; then
    cp -f "$BA_SRC/bootanimation.zip" "$MAIN_FOLDER/product/media/bootanimation.zip"
    mods "BootAnimation: product/media/bootanimation.zip <- Error OS"
else
    warn "BootAnimation: không thấy product/media - bỏ qua boot animation"
fi
# Bản China ROM của Xiaomi đôi khi chơi bootanimation từ cust_config
for themedir in "$MAIN_FOLDER"/product/media/theme/cust_config/*/; do
    if [ -d "$themedir" ]; then
        cp -f "$BA_SRC/bootanimation.zip" "$themedir/bootanimation.zip"
        mods "BootAnimation: ${themedir#$MAIN_FOLDER/}bootanimation.zip <- Error OS"
    fi
done

# 2. Wallpapers
WP_DIR="$MAIN_FOLDER/product/media/wallpapers"
mkdir -p "$WP_DIR"
copied=0
for f in "$BA_SRC"/wallpaper_*.jpg; do
    [ -f "$f" ] || continue
    cp -f "$f" "$WP_DIR/$(basename "$f")"
    copied=$((copied + 1))
done
mods "Wallpapers: +$copied hình nền Error OS vào product/media/wallpapers/"
