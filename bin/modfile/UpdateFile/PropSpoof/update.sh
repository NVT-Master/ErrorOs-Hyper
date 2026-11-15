#!/bin/bash
# ---------------------------------------------------------------------------
# Error OS PropSpoof - append 40 prop fake vao build.prop (NothingVN approach)
#
# Van de: mot so app doc truc tiep ro.boot.* va ro.* props de kiem tra unlocked.
# Khong duoc qua native getprop -> dung Java spoof (Java spoof khong du cho apps
# dung getprop native, vi native doc dung /dev/__properties__ khong qua Java).
#
# CACH: append prop moi vao build.prop de khi init parse, props co gia tri fake.
# build.prop priority THAP hon cmdline nhung NEN luu KHONG khai bao vbmeta lock.
# KHONG vbmeta locked, KHONG flash locked tru Giao dien to tinh hay interface hay gi.
#
# CACH dung: bat/cai tung propfake neu can. Xem file erroros_propspoof.ini.
# KHONG thay doi: ro.boot.verifiedbootstate (PropFix/erroros_propfix ghi life).
# ---------------------------------------------------------------------------
set +e
work_dir=$(pwd)
source "$work_dir/functions.sh"

MARKER="# >>> Error OS PropSpoof >>>"
PROPS='
# NothingVN PropSpoof (banking app sanity)
ro.boot.vbmeta.device_state=locked
ro.boot.flash.locked=1
ro.boot.veritymode=enforcing
vendor.boot.vbmeta.device_state=locked
vendor.boot.verifiedbootstate=green
vendor.boot.verifiedbootstate=green
ro.boot.warranty_bit=0
ro.warranty_bit=0
ro.vendor.boot.warranty_bit=0
ro.vendor.warranty_bit=0
ro.secure=1
ro.secureboot.devicelock=1
ro.debuggable=0
ro.build.type=user
ro.build.keys=release-keys
ro.build.tags=release-keys
ro.oem_unlock_allowed=0
ro.oem_unlock_supported=0
sys.oem_unlock_allowed=0
sys.oem_unlock_supported=0
init.svc.adbd=stopped
init.svc.flash_recovery=stopped
ro.crypto.state=encrypted
ro.miui.has_gmscore=1
ro.opa.eligible_device=true
ro.miui.support_miui_ime_bottom=1
'

FOUND=0
while IFS= read -r p; do
    [ -n "$p" ] || continue
    if ! grep -q "$MARKER" "$p" 2>/dev/null; then
        printf '%s\n%s\n%s\n' "$MARKER" "$PROPS" "# <<< Error OS PropSpoof <<<" >> "$p"
        mods "PropSpoof: append $p"
        FOUND=$((FOUND + 1))
    else
        mods "PropSpoof: da co trong $p (skip)"
    fi
done < <(find "$work_dir/build/baserom/images" -type f -name 'build.prop' 2>/dev/null)

if [ "$FOUND" -eq 0 ]; then
    mods "PropSpoof: khong thay build.prop nao co dieu kien, bo qua"
fi
exit 0
