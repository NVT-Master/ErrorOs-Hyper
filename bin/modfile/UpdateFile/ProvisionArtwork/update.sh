#!/bin/bash
# ---------------------------------------------------------------------------
# ProvisionArtwork - thay logo "Xiaomi HyperOS" trong APK Provision.apk
#
# Man hinh cuoi "Hoan thanh" trong HyperOS Setup Wizard (package chinh tai
# /system_ext/priv-app/Provision/Provision.apk) hien thi:
#   - doan text "Xiaomi HyperOS"  >> main_logo.png (990x141)
#   - main_logo_udf.png (phien ban mau khac, cung kich thuoc)
#
# Thay chu Xiaomi HyperOS thanh "ERROR OS." Dung cung style Rubik Distressed.
# Khong doi chu ky / khong ky lai APK - firmware khong verify APK preinstall
# trong ROM (AVB da tat), nen khong van de.
# ---------------------------------------------------------------------------
set +e
work_dir=$(pwd)
source "$work_dir/functions.sh"

PROV_APK="$work_dir/build/baserom/images/system_ext/priv-app/Provision/Provision.apk"
ASSET_DIR="$work_dir/artwork/logos"

if [ ! -f "$PROV_APK" ]; then
    warn "ProvisionArtwork: khong thấy $PROV_APK - bo qua (khong phai base ROM HyperOS nay)"
    exit 0
fi

rm -rf "$work_dir/jar_temp/prov_png"
mkdir -p "$work_dir/jar_temp/prov_png"

cp "$PROV_APK" "$work_dir/jar_temp/Provision.apk"

cd "$work_dir/jar_temp/prov_png" || exit 0
python3 -c "import zipfile; zipfile.ZipFile('../Provision.apk').extractall('.')"

cp "$ASSET_DIR/main_logo.png" "res/drawable-nodpi-v4/main_logo.png"
cp "$ASSET_DIR/main_logo_udf.png" "res/drawable-nodpi-v4/main_logo_udf.png"

python3 - <<'PY'
import os, zipfile
out = '../Provision.apk'
z = zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED)
for root, dirs, files in os.walk('.'):
    for f in files:
        full = os.path.join(root, f)
        arcname = full.replace('\\', '/')
        if arcname.startswith('./'):
            arcname = arcname[2:]
        z.write(full, arcname)
z.close()
PY

cd "$work_dir"
cp -f "$work_dir/jar_temp/Provision.apk" "$PROV_APK"
rm -rf "$work_dir/jar_temp/prov_png" "$work_dir/jar_temp/Provision.apk"
mods "ProvisionArtwork: main_logo -> 'ERROR OS.' (rubik distressed)"
exit 0
