#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# Error OS - setup môi trường build (Arch Linux)
set -euo pipefail

echo "[setup] Arch Linux - cài phụ thuộc qua pacman"
sudo pacman -Sy --noconfirm --needed \
    git aria2 jq rclone python python-pip wget lz4 xz zstd bc zip unzip 7zip \
    xmlstarlet erofs-utils e2fsprogs dtc zlib glibc libstdc++ \
    gcc java-runtime-headless android-tools
pip3 install --no-cache-dir ConfigObj telebot setuptools || true

echo "[setup] Done."
echo "[setup] Tiếp theo:"
echo "  bash build.sh <đường_dẫn_zip_ROM|LINK_DOWNLOAD_OTA>"
echo "  ví dụ: bash build.sh ./onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip"
