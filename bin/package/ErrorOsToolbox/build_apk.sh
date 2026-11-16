#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# ---------------------------------------------------------------------------
# Build ErrorOsToolbox.apk từ source trong thư mục này.
#
# Yêu cầu (giống máy đã build #27):
#   - WSL Linux có bash, python3, unzip, java 21 (/usr/lib/jvm/java-21-openjdk)
#   - Android SDK trên Windows: platforms/android-36/android.jar và
#     build-tools/36.0.0/{aapt.exe,zipalign.exe,lib/d8.jar,lib/apksigner.jar}
#     (đường dẫn qua /mnt/c/...; android.jar và d8/apksigner.jar được copy sang
#     /tmp để WSL gọi được)
#
# Sản phẩm: out/ErrorOsToolbox.apk (ký v2+v3 bằng keystore debug tạo mới).
# Keystore KHÔNG commit vào repo; ROM luôn cài mới qua product/app nên chữ ký
# không cần ổn định giữa các lần build. Nếu cần update tại chỗ trên máy đã
# cài, giữ nguyên keystore debug.keystore trong work dir.
#
# Sau khi build xong, copy out/ErrorOsToolbox.apk vào thư mục này (tên cố định -
# patch.sh đọc file đó) và commit.
# ---------------------------------------------------------------------------
set -e

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK=/tmp/erroros_toolbox_build
rm -rf "$WORK"
mkdir -p "$WORK/src/main/assets" "$WORK/src/main/java/com/erroros/toolbox" "$WORK/src/main/res/layout" "$WORK/src/main/res/drawable"

cp "$SRC_DIR/AndroidManifest.xml" "$WORK/src/main/AndroidManifest.xml"
cp "$SRC_DIR/main.xml" "$WORK/src/main/res/layout/main.xml"
cp "$SRC_DIR/MainActivity.java" "$WORK/src/main/java/com/erroros/toolbox/MainActivity.java"
cp "$SRC_DIR/InstallFileProvider.java" "$WORK/src/main/java/com/erroros/toolbox/InstallFileProvider.java"
# icon: script tự sinh lại bằng PIL (khối python bên dưới)
# Assets cần có: module.zip + sukisu_ultra.apk.
#   module.zip lấy từ repo: bin/package/ZygiskNextModule/ZygiskNext+AlwaysStrongInject.zip
#   sukisu_ultra.apk KHÔNG commit vào repo (manager được SukiSU patch tải
#   fresh khi build ROM). Đặt bản manager tương ứng vào bin/package/SukiSUUltra/
#   trước khi chạy script này, ví dụ copy từ RootToolbox.apk cũ (assets/sukisu_ultra.apk).
SUKISU_APK="$SRC_DIR/../SukiSUUltra/SukiSUUltra.apk"
MODULE_ZIP="$SRC_DIR/../ZygiskNextModule/ZygiskNext+AlwaysStrongInject.zip"
[ -f "$SUKISU_APK" ] || { echo "Thiếu $SUKISU_APK - đặt manager APK vào bin/package/SukiSUUltra/ trước (xem hướng dẫn đầu file). Dừng."; exit 1; }
[ -f "$MODULE_ZIP" ] || { echo "Thiếu $MODULE_ZIP trong repo. Dừng."; exit 1; }
cp "$SUKISU_APK" "$WORK/src/main/assets/sukisu_ultra.apk"
cp "$MODULE_ZIP" "$WORK/src/main/assets/module.zip"

python3 - << 'PY'
from PIL import Image, ImageDraw, ImageFont
S = 192
img = Image.new('RGBA', (S, S), (18, 18, 20, 255))
d = ImageDraw.Draw(img)
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=40, fill=(18, 18, 20, 255))
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 92)
except Exception:
    font = ImageFont.load_default()
bbox = d.textbbox((0, 0), 'E', font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
d.text(((S - tw) // 2 - 10, (S - th) // 2 - 4), 'E', font=font, fill=(255, 211, 15, 255))
d.ellipse([S - 44, S - 58, S - 16, S - 30], fill=(255, 45, 45, 255))
img.save('/tmp/erroros_toolbox_build/src/main/res/drawable/ic_launcher.png')
print('icon ok')
PY

ANDROID_JAR_SRC='/mnt/c/Program Files (x86)/Android/android-sdk/platforms/android-36/android.jar'
BT_SRC='/mnt/c/Program Files (x86)/Android/android-sdk/build-tools/36.0.0'
cp "$ANDROID_JAR_SRC" "$WORK/android.jar"
mkdir -p "$WORK/bt" "$WORK/gen" "$WORK/out"
cp "$BT_SRC/lib/d8.jar" "$WORK/bt/d8.jar"
cp "$BT_SRC/lib/apksigner.jar" "$WORK/bt/apksigner.jar"
cp "$BT_SRC/aapt.exe" "$WORK/bt/aapt.exe"
cp "$BT_SRC/zipalign.exe" "$WORK/bt/zipalign.exe"
JAR="$WORK/android.jar"
BT="$WORK/bt"

cd "$WORK"
echo "===== aapt package (+R.java)"
"$BT/aapt.exe" package -f -M src/main/AndroidManifest.xml -S src/main/res -A src/main/assets -I "$JAR" -F out/app_unsigned.apk -J gen/ --generate-dependencies
echo "===== javac"
find src/main/java -name '*.java' > sources.txt
echo "$WORK/gen/R.java" >> sources.txt
/usr/lib/jvm/java-21-openjdk/bin/javac -cp "$JAR" -d gen/ $(cat sources.txt)
echo "===== d8"
find gen/ -name '*.class' | xargs /usr/lib/jvm/java-21-openjdk/bin/java -cp "$BT/d8.jar" com.android.tools.r8.D8 --lib "$JAR" --output gen/
echo "===== add classes.dex"
cd "$WORK/gen" && "$BT/aapt.exe" add ../out/app_unsigned.apk classes.dex && cd "$WORK"
echo "===== zipalign"
"$BT/zipalign.exe" -f -p 4 out/app_unsigned.apk out/ErrorOsToolbox.apk
echo "===== sign v1+v2+v3"
KV="$WORK/debug.keystore"
if [ ! -f "$KV" ]; then
    /usr/lib/jvm/java-21-openjdk/bin/keytool -genkeypair -keystore "$KV" -alias erroros -keyalg RSA -keysize 2048 -validity 36500 -storepass android -keypass android -dname "CN=ErrorOS,O=ErrorOS,C=VN" -noprompt
fi
/usr/lib/jvm/java-21-openjdk/bin/java -jar "$BT/apksigner.jar" sign --ks "$KV" --ks-pass pass:android --ks-key-alias erroros --key-pass pass:android --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true out/ErrorOsToolbox.apk
echo "===== verify"
/usr/lib/jvm/java-21-openjdk/bin/java -jar "$BT/apksigner.jar" verify --verbose out/ErrorOsToolbox.apk | head -6
echo "-> $WORK/out/ErrorOsToolbox.apk - copy về bin/package/ErrorOsToolbox/ErrorOsToolbox.apk và commit"
