#!/bin/bash
# ---------------------------------------------------------------------------
# LunarisDolby - Dolby-style software audio effect (Equalizer + Virtualizer + EFFECT_TYPE_DAP)
# From Project Infinity-X 4.2 (AOSP, crDroid-derived, "org.lunaris.dolby").
#
# Why: adds a Dolby Atmos-like pipeline to the ROM without touching HyperOS's
# own audio stack. Pure software (no .so, no HAL) - works on top of the stock
# Android framework Equalizer/Virtualizer effect engines. Includes VI resources.
#
# Behavior on device: installs as system priv-app (org.lunaris.dolby), exposes a
# Quick Settings tile, an in-app "Dolby Atmos" settings screen, an app-profile
# auto-switcher (per-app audio profiles) using usage stats + notification
# listener. If the framework EQ/Virtualizer engines are absent the app still
# installs and runs but does nothing audible - never fatal.
#
# What we copy (mirrors Infinity-X layout):
#   system_ext/priv-app/LunarisDolby/LunarisDolby.apk   (original, NOT re-signed)
#   system_ext/etc/permissions/privapp-permissions-dolby.xml
#   system_ext/etc/sysconfig/preinstalled-packages-platform-dolby.xml
# The .odex/.vdex from Infinity-X are deliberately NOT copied - they were built
# for that ROM's exact framework fingerprint; copying would corrupt dexopt.
# Android will dexopt on first boot instead.
# ---------------------------------------------------------------------------
work_dir=${work_dir:-$(pwd)}
MAIN_FOLDER="$work_dir/build/baserom/images"
SRC_DIR="$work_dir/bin/modfile/UpdateFile/LunarisDolby"
source "$work_dir/functions.sh" 2>/dev/null || true

set_or_exit() { warn "$1"; exit 0; }

[ -d "$MAIN_FOLDER/system_ext" ] || set_or_exit "LunarisDolby: khong co system_ext trong images - bo qua"
[ -d "$SRC_DIR" ] || set_or_exit "LunarisDolby: thieu $SRC_DIR - bo qua"
[ -f "$SRC_DIR/LunarisDolby.apk" ] || set_or_exit "LunarisDolby.apk khong co - bo qua"

mkdir -p "$MAIN_FOLDER/system_ext/priv-app/LunarisDolby"
cp -f "$SRC_DIR/LunarisDolby.apk" "$MAIN_FOLDER/system_ext/priv-app/LunarisDolby/LunarisDolby.apk"

mkdir -p "$MAIN_FOLDER/system_ext/etc/permissions" "$MAIN_FOLDER/system_ext/etc/sysconfig"
[ -f "$SRC_DIR/privapp-permissions-dolby.xml" ] && \
    cp -f "$SRC_DIR/privapp-permissions-dolby.xml" "$MAIN_FOLDER/system_ext/etc/permissions/privapp-permissions-dolby.xml"
[ -f "$SRC_DIR/preinstalled-packages-platform-dolby.xml" ] && \
    cp -f "$SRC_DIR/preinstalled-packages-platform-dolby.xml" "$MAIN_FOLDER/system_ext/etc/sysconfig/preinstalled-packages-platform-dolby.xml"

mods "LunarisDolby: org.lunaris.dolby installed (system_ext priv-app)"
exit 0
