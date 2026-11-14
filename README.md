<div align="center">

# 🚀 ErrorOS-Hyper

**Error OS — custom ROM pipeline cho Xiaomi HyperOS**
_Transform official Xiaomi HyperOS China firmware into Error OS — with pixel-perfect rebrand, FCM fix, Nothing-style artwork, and integrated toolbox._

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Version](https://img.shields.io/badge/version-Error%20OS%201.1-green.svg)](#)
[![Platform](https://img.shields.io/badge/platform-Arch%20Linux-1793D1?logo=archlinux&logoColor=white)](#)

**🌐 Ngôn ngữ:** Tiếng Việt | [English](#english)

---

*Giải nén payload Xiaomi → sửa → repack → flash. Windows không chạy được.*

</div>

## ✨ Error OS có gì / What it is

Error OS là bản **fork lại hoàn chỉnh** của **BugOS-Hyper**, build từ firmware gốc **Xiaomi China `OS4.0.2.0.XOLCNXM`** (Android 17, HyperOS 4, thiết bị `onyx` — Redmi Turbo 4 Pro).

| Tính năng | Mô tả |
|---|---|
| 📦 **Base ROM gốc** | Xiaomi OS4.0.2.0.XOLCNXM (China), **không gỡ GMS/Play/Chrome** |
| 🧩 **FCM Fix (thông báo)** | Vá `miui-services.jar` Android 17 (broadcast/kill limits/force-stop), `isCnModel()=false` → GMS không bị đóng băng, FCM push luôn đến |
| 🔎 **Circle to Search** + **Gemini power-button** | Giữ nguyên từ firmware gốc |
| 🧰 **Error OS Toolbox** | Toolbox tích hợp ngay trong **Cài đặt → Toolbox** (wrench icon riêng) |
| 🎨 **Artwork riêng "ERROR OS"** | Boot animation & logo Rubik Distressed (đen chủ đạo + chấm đỏ) — xem `bin/modfile/UpdateFile/BootAnimation/` |
| ⚡ **PowerTune** | `bg_apps_limit` hợp lý; giữ pin + không lag |
| 🚀 **Root (tuỳ chọn)** | SukiSU Ultra (LKM) — bật trong `config.env`: `sukisu=true` |
| 🇻🇳 **Tiếng Việt** | Overlay Tiếng Việt cho app Xiaomi (bộ ZK Multi, đóng gói `ErrorOS.Multi.*`) |

## 📦 Hỗ trợ thiết bị

| Thiết bị | Codename | Android | Base | Trạng thái |
|---|---|---|---|---|
| Redmi Turbo 4 Pro | `onyx` | 17 / HyperOS 4 | OS4.0.2.0.XOLCNXM | ✅ Build & flash OK |

> ROM khác thiết bị khác cần tree/device riêng — chưa hỗ trợ.

## ⚙️ Build (Linux only)

### Yêu cầu
- **Arch Linux** (bắt buộc)
- ≥ **30 GB** trống, CPU ≥ 4 nhân, RAM ≥ 8 GB
- Base ROM: **`onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip`** (Xiaomi OTA full zip, ~8.7 GB — tải trực tiếp từ CDN Xiaomi)

### Các bước
```bash
git clone https://github.com/NVT-Master/ErrorOs-Hyper.git
cd ErrorOs-Hyper
bash setup.sh                          # cài phụ thuộc
bash build.sh ./onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip
# hoặc với link tải trực tiếp:
bash build.sh "https://bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com/OS4.0.2.0.XOLCNXM/onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip"
bash packROM.sh
```
Kết quả: `build/baserom/images/super.img` → nạp vào gói flash
(xem mục [Flash](#-flash)).

### Ghi chú kỹ thuật
- ZIP base phải đúng checksum full OTA (`payload.bin` bên trong).
- Build xong là images đã patch — **chưa** tự tạo gói flash; dùng script trong `bin/script2flash/`.
- CI: GitHub hosted runner không có Arch Linux — workflow chạy trong container `archlinux:latest`.

## 📱 Flash

**⚠️ Unlock bootloader trước. Flash sai → brick. Tự chịu trách nhiệm. ROM Không phải sản phẩm chính thức của Xiaomi / Nothing / Google.**

Cách 1 (recovery, khuyến nghị): OrangeFox → flash `ErrorOS_onyx_*.zip` (`update-binary` tự ghi super + images).
Cách 2 (fastboot): chạy `Windows_FastbootInstall.bat` / `Linux_FastbootInstall.sh`.
Chế độ giảm nhiệt (`CPU_CAP`) chỉnh trong `META-INF/com/google/android/update-binary`.

## 🔐 Verify
```powershell
powershell -ExecutionPolicy Bypass -File .\verify_before_flash.ps1
# 31/31 OK = gói flash hợp lệ
```

## 📜 License & Credits

GPL-3.0-or-later (xem [LICENSE](LICENSE) / [NOTICE.md](NOTICE.md) để ghi nhận chi tiết).

Error OS dựa trên **BugOS-Hyper** (KaoriTV) và tham khảo **nothingsvn_xiaomi-toolbuild**.
ZK Multi overlay Tiếng Việt (PROJECTZK), FCM fix @MMETMAmods, SukiSU Ultra, KernelSU Next,
firmware gốc Xiaomi © Xiaomi Corporation.

---

<a name="english"></a>

## English

ErrorOS-Hyper = full custom ROM build for **Xiaomi HyperOS (onyx)**, forked from **BugOS-Hyper**,
rebranded/fixed as **Error OS** (Xiaomi China `OS4.0.2.0.XOLCNXM`, Android 17 base, unmodified GMS).

- Build pipeline only (no prebuilt ROMs in git)
- Arch Linux only
- GMS kept, FCM delivery fixed for Android 17, Circle-to-Search & Gemini retained
- Not an official Xiaomi / Nothing / Google product; flash at your own risk

See **Build** section above. Arch Linux only.
