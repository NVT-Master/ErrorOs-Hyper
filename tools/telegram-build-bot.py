#!/usr/bin/env python3
"""
Error OS Build Bot — Telegram -> GitHub Actions workflow_dispatch.

Chạy 24/7 (WSL/VPS/Windows Service). Chỉ owner được quyền /build.

Env:
  TELEGRAM_BOT_TOKEN   (required)
  GITHUB_TOKEN         (required) classic PAT hoặc fine-grained với scope `actions:write`
  GITHUB_REPOSITORY    (default NVT-Master/ErrorOs-Hyper)
  TG_ALLOWED_USERS     (default trống = chỉ owner ID trong code)

Usage:
  python3 telegram-build-bot.py
"""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.error

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
GITHUB_TOKEN = os.environ.get("GITHUB_TOKEN", "").strip()
REPO = os.environ.get("GITHUB_REPOSITORY", "NVT-Master/ErrorOs-Hyper").strip()

DEFAULT_OTA_URL = "https://bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com/OS4.0.2.0.XOLCNXM/onyx-ota_full-OS4.0.2.0.XOLCNXM-user-17.0-dbe344d29d.zip"
WORKFLOW_FILE = "build.yml"
API_BASE = "https://api.github.com"

# Owner/admin IDs — phân biệt quyền trigger build.
# Thêm ID vào env TG_ALLOWED_USERS="7692468306,123456789" để mở rộng.
ENV_OWNERS = [s.strip() for s in os.environ.get("TG_ALLOWED_USERS", "").split(",") if s.strip()]
OWNER_IDS = set(["7692468306"] + ENV_OWNERS)


def tg(method, payload=None):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/{method}"
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data,
                                 headers={"Content-Type": "application/json"},
                                 method="POST")
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read().decode("utf-8"))


def gh(method, path, payload=None):
    url = f"{API_BASE}/{path.lstrip('/')}"
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={
                                     "Accept": "application/vnd.github+json",
                                     "Authorization": f"Bearer {GITHUB_TOKEN}",
                                     "X-GitHub-Api-Version": "2022-11-28",
                                     "Content-Type": "application/json",
                                 })
    with urllib.request.urlopen(req, timeout=30) as r:
        raw = r.read().decode("utf-8")
        return json.loads(raw) if raw.strip() else {}


def get_updates(offset=None, timeout_s=30):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/getUpdates"
    params = {"timeout": timeout_s}
    if offset:
        params["offset"] = offset
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    with urllib.request.urlopen(f"{url}?{qs}", timeout=timeout_s + 5) as r:
        return json.loads(r.read().decode("utf-8"))


def send(chat_id, text, reply_markup=None):
    payload = {"chat_id": chat_id, "text": text, "disable_web_page_preview": True}
    if reply_markup:
        payload["reply_markup"] = reply_markup
    tg("sendMessage", payload)


def handle_build(chat_id, args, user_id):
    if str(user_id) not in OWNER_IDS:
        send(chat_id, "❌ Bạn không có quyền build (chỉ owner mới trigger được).")
        return

    # Parse: /build [url] [mode]   (mode: root|kaorios)
    url = None
    mode = None
    for a in args:
        if a.startswith("http"):
            url = a
        elif a in ("root", "kaorios"):
            mode = a
    url = url or DEFAULT_OTA_URL
    mode = mode or "root"

    try:
        gh("POST", f"repos/{REPO}/actions/workflows/{WORKFLOW_FILE}/dispatches",
           {"ref": "main", "inputs": {"input_url": url, "toolbox_mode": mode}})
        send(chat_id,
             "🚀 Build started!\n"
             f"Branch: main | Mode: {mode}\n"
             f"URL: {url[:120]}{'…' if len(url) > 120 else ''}\n"
             "~2h sau ROM sẽ được upload + link vào group tự động.")
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", "ignore")
        send(chat_id, f"❌ Trigger thất bại HTTP {e.code}\n{err[:400]}")
    except Exception as e:
        send(chat_id, f"❌ Trigger thất bại: {e}")


def handle_id(chat_id, user_id):
    send(chat_id, f"Your Telegram ID: {user_id}\nAuthorized: {'YES' if str(user_id) in OWNER_IDS else 'NO'}")


def handle_help(chat_id, user_id):
    is_owner = str(user_id) in OWNER_IDS
    send(chat_id,
         "Error OS Build Bot\n\n"
         "/id — xem Telegram ID của bạn\n"
         "/help — hướng dẫn\n"
         + ("/build — trigger build ROM\n"
            "/build <OTA_URL> — build từ URL tùy ý\n"
            "/build root — trigger mode root (default)\n"
            "/build kaorios — build với Kaorios toolbox\n"
            if is_owner else ""))


def main():
    if not BOT_TOKEN or not GITHUB_TOKEN:
        print("Missing TELEGRAM_BOT_TOKEN or GITHUB_TOKEN env vars", file=sys.stderr)
        sys.exit(1)
    print(f"Bot started. Repo={REPO} owners={OWNER_IDS}", flush=True)

    offset = None
    while True:
        try:
            resp = get_updates(offset=offset, timeout_s=30)
        except Exception as e:
            print(f"getUpdates error: {e}", flush=True)
            time.sleep(5)
            continue

        for upd in resp.get("result", []):
            offset = upd["update_id"] + 1
            msg = upd.get("message") or upd.get("edited_message")
            if not msg:
                continue
            text = (msg.get("text") or "").strip()
            if not text:
                continue
            chat_id = msg["chat"]["id"]
            user_id = msg["from"]["id"]
            parts = text.split()
            cmd = parts[0].split("@")[0].lower()
            args = parts[1:]

            if cmd == "/id":
                handle_id(chat_id, user_id)
            elif cmd == "/help" or cmd == "/start":
                handle_help(chat_id, user_id)
            elif cmd == "/build":
                handle_build(chat_id, args, user_id)
            else:
                # im lặng với lệnh không xác định
                pass


if __name__ == "__main__":
    main()
