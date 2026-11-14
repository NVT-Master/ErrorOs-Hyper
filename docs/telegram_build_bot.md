# Error OS Telegram Build Bot — hướng dẫn

Build ROM từ nhóm bằng lệnh `/build` thay vì bấm tay qua GitHub UI.

## Cách hoạt động

```
User gõ /build trong group
       ↓
telegram-build-bot.py  (chạy 24/7 trên WSL/VPS/Windows+NSSM)
       ↓ gọi GitHub API: POST /repos/.../actions/workflows/build.yml/dispatches
Error OS ROM Build workflow  (~2h, archlinux container)
       ↓ build → pack → upload Gofile (hoặc Drive nếu có RCLONE_CONF)
notify.py tự post link vào TELEGRAM_CHANNEL_ID / TELEGRAM_GROUP_ID
```

## Cài đặt (5 bước)

### 1. Tạo GitHub PAT
- Mở https://github.com/settings/tokens?type=beta → **Generate new token (fine-grained)**
- Quyền: `Actions: Read & write` (bắt buộc) + `Contents: Read`
- Token prefix `github_pat_...`

### 2. Chuẩn bị env (ví dụ WSL Arch)
```bash
export TELEGRAM_BOT_TOKEN='<token Telegram bot>'
export GITHUB_TOKEN='<GitHub PAT>'
export GITHUB_REPOSITORY='NVT-Master/ErrorOs-Hyper'
export TG_ALLOWED_USERS='7692468306'   # Telegram user ID của bạn
```

Chạy test thử 1 lần:
```bash
python3 tools/telegram-build-bot.py
```

### 3. Chạy 24/7
**Cách đơn giản (Windows + Task Scheduler):**
```xml
<Task>
  <Actions>
    <Exec>
      <Command>wsl</Command>
      <Arguments>-d archlinux bash -lc "export TELEGRAM_BOT_TOKEN=... GITHUB_TOKEN=...; python3 /mnt/d/ErrorOS-Hyper/tools/telegram-build-bot.py >> /mnt/d/ErrorOS-Hyper/bot.log 2>&1"</Arguments>
    </Exec>
  </Actions>
  <Triggers>
    <BootTrigger /><LogonTrigger />
  </Triggers>
</Task>
```
Hoặc cài `python3-daemon` rồi: `python3 tools/telegram-build-bot.py &`

**VPS Linux:** chạy bằng systemd service:
```ini
[Unit]
Description=Error OS Telegram Build Bot
After=network.target

[Service]
Environment=TELEGRAM_BOT_TOKEN=...
Environment=GITHUB_TOKEN=...
ExecStart=/usr/bin/python3 /opt/ErrorOs-Hyper/tools/telegram-build-bot.py
Restart=always

[Install]
WantedBy=multi-user.target
```

### 4. Permissions
Bot chỉ kiểm tra ADMIN TG_ALLOWED_USERS (owner). Thêm ID khác (who tolerate 2h wait for build) vào list.

### 5. Các lệnh
| Lệnh | Mô tả |
|---|---|
| `/id` | Xem Telegram ID của bạn |
| `/help` | Hướng dẫn |
| `/build` | Trigger build mặc định |
| `/build root` | Trigger root mode (default) |
| `/build kaorios` | Trigger kaorios |
| `/build <OTA_URL>` | Build từ OTA zip khác |
| `/build <OTA_URL> kaorios` | Build từ URL khác, mode kaorios |

## Lưu ý
- Group vẫn nhận thông báo build cả khi notify.py bị lỗi (notify có `continue-on-error: true`)
- Nếu bot tắt, bấm "Run workflow" thủ công trên GitHub vẫn ra ROM
