#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# Error OS - setup môi trường build (Arch Linux)
set -euo pipefail

echo "[setup] Arch Linux - cài phụ thuộc qua pacman"
sudo pacman -Sy --noconfirm --needed \
    git aria2 jq rclone python python-pip wget lz4 xz zstd bc zip unzip 7zip \
    xmlstarlet erofs-utils e2fsprogs dtc zlib glibc libstdc++ \
    gcc java-runtime-headless android-tools jdk17-openjdk python-configobj
# Avoid PEP 668 failures on Arch/CI: prefer pacman packages, fallback to pip when needed.
if command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --noconfirm --needed python-configobj >/dev/null 2>&1 || true
fi
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import configobj" >/dev/null 2>&1 || pip3 install --no-cache-dir --break-system-packages ConfigObj >/dev/null 2>&1 || pip3 install --no-cache-dir ConfigObj >/dev/null 2>&1 || true
  python3 -c "import telebot" >/dev/null 2>&1 || pip3 install --no-cache-dir --break-system-packages telebot >/dev/null 2>&1 || pip3 install --no-cache-dir telebot >/dev/null 2>&1 || true
  python3 -c "import setuptools" >/dev/null 2>&1 || pip3 install --no-cache-dir --break-system-packages setuptools >/dev/null 2>&1 || pip3 install --no-cache-dir setuptools >/dev/null 2>&1 || true
fi

echo "[setup] Done."
echo "[setup] Tiếp theo:"
echo "  bash build.sh <đường_dẫn_zip_ROM|LINK_DOWNLOAD_OTA>"
echo "  ví dụ: bash build.sh ./onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip"
