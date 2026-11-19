#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# Error OS - setup môi trường build (Arch Linux)
set -euo pipefail

echo "[setup] Arch Linux - cài phụ thuộc qua pacman"
PACMAN_PKGS=(
  git aria2 jq rclone python python-pip wget lz4 xz zstd bc zip unzip 7zip
  xmlstarlet erofs-utils e2fsprogs dtc zlib glibc gcc-libs
  gcc android-tools jdk17-openjdk python-configobj brotli
)
# Best-effort install: avoid failing on a single renamed/missing package in some Arch snapshots.
if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then SUDO=sudo; else SUDO=""; fi
$SUDO pacman -Sy --noconfirm --needed "${PACMAN_PKGS[@]}" || {
  echo "[setup] bulk install failed, retrying per-package (best effort)..."
  for p in "${PACMAN_PKGS[@]}"; do
    $SUDO pacman -S --noconfirm --needed "$p" || echo "[setup] warning: could not install $p"
  done
}

# Ensure python tooling (avoid PEP 668 failures on Arch/CI)
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import configobj" >/dev/null 2>&1 || python3 -m pip install --no-cache-dir --break-system-packages ConfigObj >/dev/null 2>&1 || python3 -m pip install --no-cache-dir ConfigObj >/dev/null 2>&1 || pip3 install --no-cache-dir --break-system-packages ConfigObj >/dev/null 2>&1 || pip3 install --no-cache-dir ConfigObj >/dev/null 2>&1 || true
  python3 -c "import telebot" >/dev/null 2>&1 || python3 -m pip install --no-cache-dir --break-system-packages telebot >/dev/null 2>&1 || python3 -m pip install --no-cache-dir telebot >/dev/null 2>&1 || pip3 install --no-cache-dir --break-system-packages telebot >/dev/null 2>&1 || pip3 install --no-cache-dir telebot >/dev/null 2>&1 || true
  python3 -c "import setuptools" >/dev/null 2>&1 || python3 -m pip install --no-cache-dir --break-system-packages setuptools >/dev/null 2>&1 || python3 -m pip install --no-cache-dir setuptools >/dev/null 2>&1 || pip3 install --no-cache-dir --break-system-packages setuptools >/dev/null 2>&1 || pip3 install --no-cache-dir setuptools >/dev/null 2>&1 || true
fi

echo "[setup] Done."
echo "[setup] Tiếp theo:"
echo "  bash build.sh <đường_dẫn_zip_ROM|LINK_DOWNLOAD_OTA>"
echo "  ví dụ: bash build.sh ./onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip"
