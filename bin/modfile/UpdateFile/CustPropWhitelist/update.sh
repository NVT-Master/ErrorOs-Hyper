#!/bin/bash
# ---------------------------------------------------------------------------
# CustPropWhitelist - append cac fake boot props vao MIUI cust whitelist de
# MIUI khong reset reset/delete props sau boot.
#
# OS4 HyperOS duyet properties thong qua etc/cust_prop_white_keys_list; props
# ngoai whitelist co the bi reset ve default trong cust_processing ( cust ).
#
# KHONG khoa bootloader. KHONG vbmeta lock. NATURAL.
# ---------------------------------------------------------------------------
set +e
work_dir=$(pwd)
source "$work_dir/functions.sh"

# NothingVN proven list of properties that must survive on HyperOS
KEYS='ro.boot.verifiedbootstate
ro.boot.vbmeta.device_state
ro.boot.flash.locked
ro.boot.veritymode
vendor.boot.verifiedbootstate
vendor.boot.vbmeta.device_state
ro.boot.warranty_bit
ro.warranty_bit
ro.vendor.boot.warranty_bit
ro.vendor.warranty_bit
ro.secure
ro.secureboot.devicelock
ro.debuggable
ro.build.type
ro.build.keys
ro.build.tags
ro.oem_unlock_allowed
ro.oem_unlock_supported
ro.crypto.state
ro.miui.has_gmscore
ro.opa.eligible_device
ro.miui.support_miui_ime_bottom'

FOUND=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    MARK="# erroros-whitelist"
    if grep -qF "$MARK" "$f" 2>/dev/null; then
        mods "CustWhitelist: da co trong $f (skip)"
        continue
    fi
    {
        echo "$MARK"
        printf '%s\n' "$KEYS"
    } >> "$f"
    mods "CustWhitelist: append 23 key vao $f"
    FOUND=$((FOUND + 1))
done < <(find "$work_dir/build/baserom/images" -type f -name 'cust_prop_white_keys_list' 2>/dev/null)

if [ "$FOUND" -eq 0 ]; then
    mods "CustWhitelist: khong thay cust_prop_white_keys_list tren base OS4 - bo qua (system/product van du doc props)"
fi
exit 0
