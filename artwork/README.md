# Error OS artwork

Bộ artwork chính thức: logo Giới thiệu (About), wallpaper mặc định, boot animation
(`ERROR OS` Rubik Distressed + nền đen→đỏ + glitch tagline `// BREAK THE SYSTEM`).

## Files

| File | Vai trò |
|---|---|
| `fonts/RubikDistressed-Regular.ttf` | Font **Rubik Distressed** (OFL, trong repo) |
| `fonts/RubikDistressed-OFL.txt` | License Rubik Distressed (SIL OFL 1.1) |
| `gen_erroros_art.py` | Generator: About logo, wallpapers, boot frames + zip |
| `examples/logo_light.png` | Logo About (nền sáng) — đã commit, ROM dùng luôn |
| `examples/logo_dark.png` | Logo About (nền tối) — đã commit, ROM dùng luôn |
| `examples/wallpaper_break.png` | Wallpaper mặc định 1 |
| `examples/wallpaper_dot.png` | Wallpaper mặc định 2 |
| `examples/boot_preview.mp4` | Video preview boot animation |

## Regenerate

```bash
pacman -S --noconfirm --needed python python-pillow python-numpy
python3 gen_erroros_art.py all
# output trong ./out/: logo_light.png, logo_dark.png, wallpaper_*.png, boot/part0/*.png, bootanimation.zip
```

Đổi chữ "BREAK THE SYSTEM" / `ERROR OS` trong chính `gen_erroros_art.py`
(`make_lockup`, `render_wallpaper_break`, `readouts`).

## About logo trong ROM

`bin/modfile/UpdateFile/Settings_ROMInformation/logo_light.png` và `logo_dark.png`
chính là bản từ pipeline này. Khi build ROM cho base khác phải regenerate hoặc copy
lại file từ `examples/`.

## Wallpaper trong ROM

`bin/modfile/UpdateFile/BootAnimation/wallpaper_*.jpg` — chăm sóc cho mọi base ROM:
tự động đưa vào `product/media/wallpapers/` qua `update.sh`.

## Boot animation trong ROM

`bin/modfile/UpdateFile/BootAnimation/bootanimation.zip` — thay `product/media/bootanimation.zip`.

## License fonts

Rubik Distressed — **SIL Open Font License 1.1** (xem `fonts/RubikDistressed-OFL.txt`).
