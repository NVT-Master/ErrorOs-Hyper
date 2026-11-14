#!/usr/bin/env python3
# Error OS artwork generator — logos (About), wallpapers (default 2), boot animation
# Run: python3 gen.py all
# Requirements: python3 + python-pillow + python-numpy

"""Error OS - Cyberpunk Glitch artwork generator.

Outputs:
  boot/part0/*.png        - 1280x2772 boot animation frames (30 fps)
  logo_light.png          - Settings About wordmark, dark-on-transparent (light theme)
  logo_dark.png           - Settings About wordmark, white-on-transparent (dark theme)
  wallpaper_break.png     - default wallpaper "Break The System"
  wallpaper_dot.png       - minimal wallpaper single red dot

Palette (cyberpunk glitch, monochrome + red accent on black):
  BG      #050505   ink white #F2F2F2   gray #8E8E8E / #3A3A3A
  RED     #FF2D2D   deep red glow #5A0A12   cyan fringe #00E5FF (aberration only)
"""
import math
import os
import sys
import random
import numpy as np
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1280, 2772
BG = (5, 5, 6)
WHITE = (242, 242, 242)
RED = (255, 45, 45)
RED_DEEP = (90, 10, 18)
CYAN = (0, 229, 255)
GRAY = (142, 142, 142)
GRAY_DIM = (58, 58, 58)

F_BLACK   = "/usr/share/fonts/TTF/Roboto-Black.ttf"
F_BOLD    = "/usr/share/fonts/TTF/Roboto-Bold.ttf"
F_REG     = "/usr/share/fonts/TTF/Roboto-Regular.ttf"
_fcondb = "/usr/share/fonts/TTF/RobotoCondensed-Bold.ttf"
F_CONDB = _fcondb if os.path.exists(_fcondb) else F_MONO
_fm = "/usr/share/fonts/TTF/DejaVuSansMono.ttf"
F_MONO = _fm if os.path.exists(_fm) else "/usr/share/fonts/TTF/LiberationMono-Regular.ttf"
_fmb = "/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf"
F_MONOB = _fmb if os.path.exists(_fmb) else F_MONO

# hybrid wordmark fonts (user-picked)
F_ERR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts/RubikDistressed-Regular.ttf")
F_OSB = F_ERR

def font(path, size):
    return ImageFont.truetype(path, size)

# ---------------------------------------------------------------- backdrop
def base_canvas():
    img = Image.new("RGB", (W, H), BG)
    grad = np.zeros((H, W, 3), dtype=np.float32)
    yy = np.linspace(0, 1, H)[:, None, None]
    grad += (16, 17, 24) * (1 - yy) * 0.40
    red_glow = np.clip((yy - 0.60) / 0.40, 0, 1) ** 2.0
    grad += red_glow * np.array([60, 9, 12], dtype=np.float32)
    center = np.clip(1 - np.abs(yy - 0.42) / 0.42, 0, 1)
    grad += center * np.array([13, 13, 14], dtype=np.float32)
    arr = np.clip(np.asarray(img, dtype=np.float32) + grad, 0, 255).astype(np.uint8)
    img = Image.fromarray(arr)
    vign = Image.new("L", (W, H), 0)
    dv = ImageDraw.Draw(vign)
    dv.ellipse([-W * 0.42, -H * 0.26, W * 1.42, H * 1.26], fill=210)
    vign = vign.filter(ImageFilter.GaussianBlur(240))
    black = Image.new("RGB", (W, H), (0, 0, 0))
    img = Image.composite(img, black, vign.point(lambda v: int(v * 0.92)))
    return img

def dot_grid(img, spacing=30, radius=1.6, alpha=22, center_boost=True):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for y in range(spacing // 2, H, spacing):
        for x in range(spacing // 2, W, spacing):
            a = alpha
            if center_boost:
                # slightly brighter in logo zone
                dy = abs(y - H * 0.47) / (H * 0.5)
                a = int(alpha + (1 - min(1, dy)) * 26)
            d.ellipse([x - radius, y - radius, x + radius, y + radius], fill=(255, 255, 255, a))
    img.paste(overlay, (0, 0), overlay)
    return img

def scanlines(img, step=4, alpha=26):
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    for y in range(0, H, step):
        d.line([(0, y), (W, y)], fill=(0, 0, 0, alpha), width=1)
    img.paste(overlay, (0, 0), overlay)
    return img

def corner_brackets(img, inset=64, size=52, width=5, color=RED, alpha=210):
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    c = color + (alpha,)
    for ox, oy, sx, sy in ((inset, inset, 1, 1), (W - inset, inset, -1, 1),
                           (inset, H - inset, 1, -1), (W - inset, H - inset, -1, -1)):
        d.line([(ox, oy), (ox + sx * size, oy)], fill=c, width=width)
        d.line([(ox, oy), (ox, oy + sy * size)], fill=c, width=width)
    base = img.convert("RGBA")
    base = Image.alpha_composite(base, ov)
    return base.convert("RGB")

def noise(img, pct=0.035, seed=0):
    rnd = np.random.default_rng(seed)
    arr = np.asarray(img).astype(np.int16)
    mask = rnd.random(arr.shape[:2]) < pct
    sparks = rnd.integers(0, 256, arr.shape[:2]).astype(np.int16)
    # add HDR-ish sparkle instead of replace
    for ch in range(3):
        arr[:, :, ch] = np.where(mask, np.clip(arr[:, :, ch] + sparks // 3, 0, 255), arr[:, :, ch])
    return Image.fromarray(arr.astype(np.uint8))

def h_bars(img, n, max_h=60, rng=None):
    """Glitch horizontal bars: slice band, offset it, add red/cyan fringe."""
    rng = rng or random.Random(1)
    arr = np.asarray(img).copy()
    for _ in range(n):
        y0 = rng.randint(int(H * 0.18), int(H * 0.78))
        bh = rng.randint(6, max_h)
        dx = rng.choice([-1, 1]) * rng.randint(8, 46)
        y1 = min(H, y0 + bh)
        band = np.roll(arr[y0:y1], dx, axis=1)
        # channel split within band
        band_r = np.roll(arr[y0:y1], dx - 3, axis=1)[:, :, 0]
        band_b = np.roll(arr[y0:y1], dx + 3, axis=1)[:, :, 2]
        band[:, :, 0] = band_r
        band[:, :, 2] = band_b
        arr[y0:y1] = band
    return Image.fromarray(arr)

# ---------------------------------------------------------------- wordmark
WM_TEXT = "ERROR OS"

def draw_wordmark(draw, xy, size, fill, tracking=0, fontpath=F_BLACK):
    f = font(fontpath, size)
    x, y = xy
    for ch in WM_TEXT:
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + tracking
    return x

def wm_size(draw, size, tracking=0, fontpath=F_BLACK):
    f = font(fontpath, size)
    return sum(draw.textlength(ch, font=f) for ch in WM_TEXT) + tracking * (len(WM_TEXT) - 1)

def fit_wordmark(draw, target_w, fontpath=F_BLACK):
    size = 10
    while wm_size(draw, size + 1, fontpath=fontpath) <= target_w:
        size += 1
    return size

def text_center(draw, cx, y, text, fnt, fill, tracking=0):
    widths = [draw.textlength(ch, font=fnt) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = cx - total / 2
    for ch, wch in zip(text, widths):
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += wch + tracking

def glow_layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))

def composite_glow(img, layer, blur, opacity=255):
    glow = layer.filter(ImageFilter.GaussianBlur(blur))
    if opacity < 255:
        glow = glow.point(lambda v: int(v * opacity / 255))
    img.paste(glow, (0, 0), glow)
    return img

# ================================================================
# Error OS lockup renderer
# ================================================================
def alpha_scale(layer, k):
    r, g, b, a = layer.split()
    a = a.point(lambda v: int(v * k))
    return Image.merge("RGBA", (r, g, b, a))

OUT = os.environ.get("OUT", os.path.join(os.getcwd(), "out"))
CK = OUT

FONT_OPTS = {
    "roboto-black": "/usr/share/fonts/TTF/Roboto-Black.ttf",
    "permanent-marker": "/home/nvt/erroros_fonts/PermanentMarker-Regular.ttf",
    "rubik-distressed": "/home/nvt/erroros_fonts/RubikDistressed-Regular.ttf",
    "rubik-dirt": "/home/nvt/erroros_fonts/RubikDirt-Regular.ttf",
    "rock-salt": "/home/nvt/erroros_fonts/RockSalt-Regular.ttf",
}

CY = H * 0.415          # (unused)
ERROR_TOP = int(H * 0.355)
TAG_Y = int(H * 0.655)


def tracked_width(draw, text, fnt, tracking=0):
    return sum(draw.textlength(ch, font=fnt) for ch in text) + tracking * (len(text) - 1)


def draw_tracked(draw, x, y, text, fnt, fill, tracking=0):
    for ch in text:
        draw.text((x, y), ch, font=fnt, fill=fill)
        x += draw.textlength(ch, font=fnt) + tracking
    return x


def text_bbox_size(draw, text, fnt):
    b = draw.textbbox((0, 0), text, font=fnt)
    return b[2] - b[0], b[3] - b[1]


def make_lockup(err_font, os_font, size=290, glyph_alpha=None, jitter=None,
                underscore_on=True, tagline="", tag_full="", red_dot_color=RED):
    """Render the 'ERROR OS' hybrid lockup to an RGBA layer."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    while True:
        f_err = font(err_font, size)
        f_os = font(os_font, int(size * 1.02))
        f_tag = font(F_CONDB, 36)
        we = tracked_width(d, "ERROR", f_err, 6)
        if we <= 1130 or size <= 120:
            break
        size -= 8

    # ---- ERROR (brush, upper line)
    x = (W - we) / 2
    for i, ch in enumerate("ERROR"):
        a = glyph_alpha(i) if glyph_alpha else 255
        dx = jitter(i) if jitter else 0
        d.text((x + dx, ERROR_TOP), ch, font=f_err, fill=(*WHITE, a))
        x += d.textlength(ch, font=f_err) + 6

    # ---- red divider under ERROR
    div_y = ERROR_TOP + int(size * 1.30)
    div_w, div_h = 400, 7
    div_x = (W - div_w) / 2
    d.rectangle([div_x, div_y, div_x + div_w, div_y + div_h], fill=(*red_dot_color, 235))

    # ---- OS (Roboto Black, second line) + red underscore
    os_text = "OS"
    f_os = font(os_font, int(size * 1.02))
    wo = tracked_width(d, os_text, f_os, 16)
    us_w, gap = int(size * 0.52), 20
    total = wo + (gap + us_w if underscore_on else 0)
    x = (W - total) / 2
    base_y = div_y + div_h + int(size * 0.18)
    a = glyph_alpha(6) if glyph_alpha else 255
    dx = jitter(6) if jitter else 0
    for ch in os_text:
        d.text((x + dx, base_y), ch, font=f_os, fill=(*WHITE, a))
        x += d.textlength(ch, font=f_os) + 16
    if underscore_on:
        uy = base_y + int(size * 0.82)
        us_x = x - 16 + gap
        d.rectangle([us_x, uy, us_x + us_w, uy + 16], fill=(*RED, 255 if a >= 100 else a))

    # ---- tagline
    if tagline:
        tag_full = tag_full or tagline
        prefix = "// "
        wp = tracked_width(d, prefix + tag_full, f_tag, 7)
        x = (W - wp) / 2
        d.text((x, TAG_Y), prefix, font=f_tag, fill=(*RED, 235))
        x += d.textlength(prefix, font=f_tag) + 7
        shown = tag_full[:len(tagline)]
        draw_tracked(d, x, TAG_Y, shown, f_tag, (*(217, 217, 217), 235), 7)

    return layer

# ================================================================
# Boot animation renderer — 30 fps, ~132 frames
# ================================================================
N_FRAMES = 132
GAP = 0

def add_noise(img, pct=0.03, seed=0):
    rnd = np.random.default_rng(seed)
    arr = np.asarray(img).astype(np.int16)
    mask = rnd.random(arr.shape[:2]) < pct
    sparks = rnd.integers(40, 256, arr.shape[:2]).astype(np.int16)
    # colored sparkle: mostly white, 20% red, 10% cyan
    r = rnd.random(arr.shape[:2])
    add = np.zeros_like(arr)
    add[:, :, 0] = np.where(mask, np.where(r < 0.2, sparks, np.where(r < 0.3, 20, sparks // 2)), 0)
    add[:, :, 1] = np.where(mask, np.where(r < 0.2, sparks // 4, np.where(r < 0.3, sparks // 3, sparks // 2)), 0)
    add[:, :, 2] = np.where(mask, np.where(r < 0.2, sparks // 4, np.where(r < 0.3, sparks, sparks // 2)), 0)
    arr = np.clip(arr + add, 0, 255).astype(np.uint8)
    return Image.fromarray(arr)

def fringe_layer(base_layer, dx, color):
    """Solid-color offset copy of base_layer (for chromatic aberration)."""
    tinted = Image.new("RGBA", base_layer.size, (0, 0, 0, 0))
    # recolor: use alpha channel of base_layer as mask
    alpha = base_layer.split()[3]
    tinted.paste(color + (255,), (0, 0), alpha)
    return tinted.transform(tinted.size, Image.AFFINE, (1, 0, -dx, 0, 1, 0), resample=Image.BICUBIC)

def blur_bbox(layer, blur):
    bbox = layer.getbbox()
    if not bbox:
        return layer
    pad = blur * 4
    box = (max(0, bbox[0] - pad), max(0, bbox[1] - pad),
           min(layer.width, bbox[2] + pad), min(layer.height, bbox[3] + pad))
    crop = layer.crop(box)
    crop = crop.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    out.paste(crop, box[:2])
    return out

def glyph_schedule():
    # appear frame for: E,R,R,O,R (top line), O,S (second line handled together)
    return {0: 14.0, 1: 16.0, 2: 18.0, 3: 20.0, 4: 22.0}

def render_boot_frame(f, fontpath, out_dir):
    img = base_canvas()
    seed = f * 7919 + 13
    rng = random.Random(seed)

    # dot grid fades in f=6..16
    grid_a = 0 if f < 6 else min(1.0, (f - 6) / 10)
    if grid_a > 0:
        dot_grid(img, spacing=30, radius=1.6, alpha=int(26 * grid_a), center_boost=True)

    # ---------- phase B: power line (f 2..5)
    if 2 <= f <= 5:
        ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(ov)
        prog = {2: 0.36, 3: 0.72, 4: 1.0, 5: 1.0}[f]
        lw = int(W * prog)
        x0, x1 = (W - lw) // 2, (W + lw) // 2
        d.rectangle([x0, H // 2 - 2, x1, H // 2 + 2], fill=(255, 255, 255, 235))
        img.paste(ov, (0, 0), ov)
        img = blur_bbox(img.convert("RGBA"), 6).convert("RGB")
        if f == 5:
            img = img.point(lambda v: min(255, int(v * 1.25)))

    if f >= 6:
        # ---------- phase C: noise storm decay f 6..13
        if f <= 13:
            storm = max(0.0, 1.0 - (f - 6) / 7.5)
            img = add_noise(img, pct=0.055 * storm + 0.012, seed=seed)
            arr = np.asarray(img).copy()
            for _ in range(int(rng.randint(3, 6) * storm + 1)):
                y0 = rng.randint(int(H * 0.2), int(H * 0.8))
                bh = rng.randint(8, int(60 * storm) + 6)
                dx = rng.choice([-1, 1]) * rng.randint(6, int(52 * storm) + 8)
                y1 = min(H, y0 + bh)
                band = np.roll(arr[y0:y1], dx, axis=1)
                arr[y0:y1] = band
            img = Image.fromarray(arr)

        # ---------- phase D/E: lockup
        if f >= 13:
            sched = glyph_schedule()

            def g_alpha(i):
                t = sched.get(i, 23.5)
                return int(np.clip((f - t) / 2.4, 0, 1) * 255)

            def jitter(i):
                t = sched.get(i, 23.5)
                rem = max(0.0, t + 3.6 - f)
                return rng.uniform(-1, 1) * rem * 9

            us_on = (f % 30) < 19 if f >= 26 else True
            tag_n = 0
            if f >= 34:
                tag_n = min(len("BREAK THE SYSTEM"), (f - 34) // 2 + 1)
            lock = make_lockup(F_ERR, F_OSB, size=290,
                               glyph_alpha=g_alpha, jitter=jitter,
                               underscore_on=us_on,
                               tagline=("BREAK THE SYSTEM"[:tag_n] if tag_n else ""),
                               tag_full="BREAK THE SYSTEM")
            # chromatic fringe during materialize + early hold
            fr = 0.0
            if f < 32:
                fr = max(0.0, (32 - f) / 19.0)
            elif f in (47, 71, 96):
                fr = 0.5
            if fr > 0.02:
                off = int(round(9 * fr)) or 1
                red_l = fringe_layer(lock, -off, RED)
                cyn_l = fringe_layer(lock, off, CYAN)
                img = img.convert("RGBA")
                img = Image.alpha_composite(img, alpha_scale(cyn_l, 0.55))
                img = Image.alpha_composite(img, alpha_scale(red_l, 0.55))
                img = img.convert("RGB")
            # glow
            glow_red = Image.new("RGBA", lock.size, (0, 0, 0, 0))
            gr = ImageDraw.Draw(glow_red)
            alpha = lock.split()[3].point(lambda v: int(v * 0.5))
            glow_red.paste((255, 45, 45, 120), (0, 0), alpha)
            glow_red = blur_bbox(glow_red, 42)
            img = img.convert("RGBA")
            img = Image.alpha_composite(img, glow_red)
            img = Image.alpha_composite(img, lock)
            img = img.convert("RGB")

        # ---------- phase F: hold micro-glitch bursts
        if f >= 26:
            bursts = {33: 2, 40: 3, 52: 3, 63: 2, 78: 4, 88: 2, 100: 2, 112: 3}
            # trigger if f or f-1 in bursts (2-frame burst)
            nb = bursts.get(f, bursts.get(f - 1, 0))
            if nb:
                img = h_bars(img, nb, max_h=26, rng=rng)
            img = add_noise(img, pct=0.006, seed=seed + 5)

        # ---------- readouts (appear from f 14)
        if f >= 14:
            ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            d = ImageDraw.Draw(ov)
            f_mi = font(F_MONO, 19)
            f_mi_b = font(F_MONOB, 19)
            col = (110, 110, 110, 220)
            d.text((78, H - 190), "onyx // 25053RT47C", font=f_mi, fill=col)
            rt = "OS 1.1"
            d.text((W - 78 - d.textlength(rt, font=f_mi), H - 190), rt, font=f_mi, fill=col)
            if f % 3 == 0:
                hx = f"0x{(seed * 2654435761 % 0xFFFFFFFF):08X}"
                d.text((W // 2 - d.textlength(hx, font=f_mi) / 2, H - 138), hx, font=f_mi, fill=(86, 86, 86, 200))
            d.text((W // 2 - d.textlength("NOTHING IS FINE.", font=f_mi) / 2, 210),
                   "NOTHING IS FINE.", font=f_mi, fill=(78, 78, 78, 200))
            d.text((W // 2 - d.textlength("SYS/ERR // BOOT_SEQ 0xDEADBEEF", font=f_mi) / 2, 254),
                   "SYS/ERR // BOOT_SEQ 0xDEADBEEF", font=f_mi, fill=(96, 96, 96, 220))
            img = img.convert("RGBA")
            img = Image.alpha_composite(img, ov)
            img = img.convert("RGB")

        # corner brackets (pulse)
        pulse = 0.72 + 0.28 * math.sin(f * 0.11)
        corner_brackets(img, inset=58, size=54, width=5, color=RED, alpha=int(220 * pulse))

    img = scanlines(img, step=4, alpha=24)

    # ---------- phase G: fade out f 97..118
    if f >= 97:
        t = np.clip((f - 97) / 22.0, 0, 1)
        ease = t * t * (3 - 2 * t)
        arr = np.asarray(img).astype(np.float32)
        # keep red floor glow slightly longer: fade luminance not hue entirely
        arr *= (1 - ease * 0.96)
        img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))

    # ---------- final frames: single red dot dying
    if f >= 119:
        arr = np.asarray(img) // 4
        img = Image.fromarray(arr)
        fade = np.clip(1 - (f - 119) / 10.0, 0, 1)
        if fade > 0:
            ov = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            d = ImageDraw.Draw(ov)
            d.ellipse([W // 2 - 9, H // 2 - 9, W // 2 + 9, H // 2 + 9],
                      fill=(255, 45, 45, int(200 * fade)))
            img = img.convert("RGBA")
            img = Image.alpha_composite(img, ov)
            img = img.convert("RGB")

    out_dir = os.path.join(out_dir, "part0")
    os.makedirs(out_dir, exist_ok=True)
    img.save(os.path.join(out_dir, f"{f:02d}.png"))
    return img


def render_boot(fontpath, out_root=OUT):
    frames_dir = os.path.join(out_root, "boot")
    os.makedirs(frames_dir, exist_ok=True)
    for f in range(N_FRAMES):
        render_boot_frame(f, fontpath, frames_dir)
        if f % 20 == 0:
            print(f"frame {f}", flush=True)
    with open(os.path.join(frames_dir, "desc.txt"), "w", newline="\n") as fh:
        fh.write("1280 2772 30\nc 1 0 part0\n")
    print("boot frames done")


def contact_sheet(src_dir, n=10, scale=0.25):
    imgs = [Image.open(os.path.join(src_dir, f"part0/{f:02d}.png")) for f in
            [0, 2, 4, 7, 10, 16, 20, 25, 30, 40, 60, 80, 100, 110, 118, 125, 130, 131]]
    fw, fh = imgs[0].size
    tw, th = int(fw * scale), int(fh * scale)
    cols = 6
    rows = math.ceil(len(imgs) / cols)
    sheet = Image.new("RGB", (tw * cols + 20 * (cols + 1), th * rows + 20 * (rows + 1)), (18, 18, 20))
    for i, im in enumerate(imgs):
        im = im.resize((tw, th), Image.LANCZOS)
        r, c = divmod(i, cols)
        sheet.paste(im, (20 + c * (tw + 20), 20 + r * (th + 20)))
    os.makedirs(CK, exist_ok=True)
    dst = os.path.join(CK, "boot_contact_sheet.jpg")
    sheet.save(dst, quality=90)
    print("contact sheet:", dst)

# ================================================================
# Option comparison cards / logos / wallpapers
# ================================================================
def wordmark_cards():
    """Render one full-size hybrid preview frame for comparison."""
    img = base_canvas()
    dot_grid(img, spacing=30, radius=1.6, alpha=26)
    lock = make_lockup(F_ERR, F_OSB, size=292, underscore_on=True,
                       tagline="BREAK THE SYSTEM", tag_full="BREAK THE SYSTEM")
    gr = Image.new("RGBA", lock.size, (0, 0, 0, 0))
    gr.paste((255, 45, 45, 120), (0, 0), alpha_scale(lock, 0.45).split()[3])
    gr = blur_bbox(gr, 44)
    comp = Image.alpha_composite(img.convert("RGBA"), gr)
    comp = Image.alpha_composite(comp, lock).convert("RGB")
    corner_brackets(comp, inset=58, size=54, width=5, color=RED, alpha=150)
    os.makedirs(CK, exist_ok=True)
    dst = os.path.join(CK, "hybrid_preview.jpg")
    comp.save(dst, quality=90)
    print("cards:", dst)

def render_logo(text_rgb, dot_rgb, dst, size=520):
    f1 = font(F_ERR, size)
    f2 = font(F_BLACK, int(size * 1.02))
    img = Image.new("RGBA", (3095, 1039), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w1 = d.textlength("ERROR", font=f1) + d.textlength(" ", font=f1)
    w2 = d.textlength("OS", font=f2) + 14
    w3 = d.textlength(".", font=f2)
    total = w1 + w2 + w3
    b1 = d.textbbox((0, 0), "ERROR", font=f1)
    b2 = d.textbbox((0, 0), "OS", font=f2)
    h1 = b1[3] - b1[1]
    y = (1039 - h1) / 2 - b1[1]
    y2 = y + (b1[3] - b2[3])          # align ink bottoms (baselines)
    x = (3095 - total) / 2
    d.text((x, y), "ERROR ", font=f1, fill=text_rgb + (255,))
    d.text((x + w1, y2), "OS", font=f2, fill=text_rgb + (255,))
    d.text((x + w1 + w2, y2), ".", font=f2, fill=dot_rgb + (255,))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    img.save(dst)
    print("logo:", dst)

def render_logos(_fontpath=None):
    render_logo((20, 20, 22), (224, 32, 32), os.path.join(OUT, "logo_light.png"), size=520)
    render_logo((242, 242, 242), (255, 45, 45), os.path.join(OUT, "logo_dark.png"), size=520)

def render_wallpaper_break(fontpath):
    img = base_canvas()
    dot_grid(img, spacing=30, radius=1.6, alpha=26)
    lock = make_lockup(F_ERR, F_OSB, size=300, underscore_on=True,
                       tagline="BREAK THE SYSTEM", tag_full="BREAK THE SYSTEM")
    gr = Image.new("RGBA", lock.size, (0, 0, 0, 0))
    gr.paste((255, 45, 45, 110), (0, 0), alpha_scale(lock, 0.4).split()[3])
    gr = blur_bbox(gr, 46)
    img = Image.alpha_composite(img.convert("RGBA"), gr)
    img = Image.alpha_composite(img, lock).convert("RGB")
    img = scanlines(img, step=4, alpha=20)
    corner_brackets(img, inset=58, size=60, width=5, color=RED, alpha=140)
    d = ImageDraw.Draw(img, "RGBA")
    f_mi = font(F_MONO, 20)
    col = (110, 110, 110, 190)
    d.text((78, H - 190), "onyx // 25053RT47C", font=f_mi, fill=col)
    rt = "OS 1.1"
    d.text((W - 78 - d.textlength(rt, font=f_mi), H - 190), rt, font=f_mi, fill=col)
    img.save(os.path.join(OUT, "wallpaper_break.png"))
    print("wallpaper_break.png")

def render_wallpaper_dot():
    img = Image.new("RGB", (W, H), BG)
    dot_grid(img, spacing=44, radius=1.5, alpha=16, center_boost=False)
    # red arch glow from bottom
    d = ImageDraw.Draw(img, "RGBA")
    grad = Image.new("RGB", (W, H))
    gd = ImageDraw.Draw(grad)
    for yy in range(H):
        t = np.clip((yy / H - 0.55) / 0.45, 0, 1) ** 2.2
        gd.line([(0, yy), (W, yy)], fill=(int(64 * t), int(8 * t), int(10 * t)))
    img = Image.blend(img, grad, 0.85)
    # the dot
    cy = int(H * 0.40)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(glow)
    g.ellipse([W // 2 - 150, cy - 150, W // 2 + 150, cy + 150], fill=(255, 45, 45, 120))
    glow = glow.filter(ImageFilter.GaussianBlur(70))
    base = img.convert("RGBA")
    base = Image.alpha_composite(base, glow)
    d = ImageDraw.Draw(base, "RGBA")
    d.ellipse([W // 2 - 54, cy - 54, W // 2 + 54, cy + 54], fill=(255, 45, 45, 255))
    d.ellipse([W // 2 - 54, cy - 54, W // 2 + 54, cy + 54], outline=(255, 150, 150, 180), width=2)
    # micro captions
    f_mi = font(F_MONO, 24)
    cap = "E R R O R   O S"
    w = d.textlength(cap, font=f_mi)
    d.text((W // 2 - w / 2, cy + 210), cap, font=f_mi, fill=(200, 200, 200, 235))
    f_mi_s = font(F_MONO, 18)
    cap2 = "BREAK THE SYSTEM"
    w2 = d.textlength(cap2, font=f_mi_s)
    d.text((W // 2 - w2 / 2, cy + 258), cap2, font=f_mi_s, fill=(150, 60, 60, 235))
    base = base.convert("RGB")
    corner_brackets(base, inset=58, size=54, width=5, color=RED, alpha=90)
    base.save(os.path.join(OUT, "wallpaper_dot.png"))
    print("wallpaper_dot.png")

if __name__ == "__main__":
    import sys as _sys
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(CK, exist_ok=True)
    cmd = _sys.argv[1] if len(_sys.argv) > 1 else "cards"
    font_name = _sys.argv[2] if len(_sys.argv) > 2 else "roboto-black"
    fp = FONT_OPTS.get(font_name, FONT_OPTS["roboto-black"])
    if cmd == "cards":
        wordmark_cards()
    elif cmd == "boot":
        render_boot(fp)
        contact_sheet(os.path.join(OUT, "boot"))
    elif cmd == "logos":
        render_logos(fp)
    elif cmd == "wallpapers":
        render_wallpaper_break(fp)
        render_wallpaper_dot()
    elif cmd == "all":
        render_logos(fp)
        render_wallpaper_break(fp)
        render_wallpaper_dot()
        render_boot(fp)
        contact_sheet(os.path.join(OUT, "boot"))
    else:
        print("unknown cmd:", cmd)
        _sys.exit(2)
