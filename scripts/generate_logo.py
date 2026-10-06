"""Generates the app's brand assets from one drawing:

  assets/branding/logo.png             512px full logo (gradient disc + cap),
                                       used by the splash/login screens and the
                                       native Android splash
  assets/branding/logo_foreground.png  1024px cap + sparkles only, transparent
  android/app/src/main/res/mipmap-*/ic_launcher.png             legacy launcher icons
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  adaptive foreground
  android/app/src/main/res/drawable/ic_launcher_background.xml  adaptive background
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml    adaptive icon

Palette matches the app theme (lib/theme/app_theme.dart): violet #7C4DFF to
blue #2979FF on deep violet. Run: python scripts/generate_logo.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

S = 2048  # work at 2x and downsample for smooth edges
VIOLET = (139, 92, 255)
BLUE = (41, 121, 255)
WHITE = (255, 255, 255, 255)
LAVENDER = (226, 217, 255, 255)
GOLD = (255, 200, 87, 255)


def diagonal_gradient(size, c1, c2):
    """Top-left c1 -> bottom-right c2."""
    grad = Image.new("RGB", (size, size))
    px = grad.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))
    return grad


def star(draw, cx, cy, r, fill):
    """Four-point sparkle."""
    inner = r * 0.22
    pts = []
    for i in range(8):
        ang = math.pi / 4 * i - math.pi / 2
        rad = r if i % 2 == 0 else inner
        pts.append((cx + rad * math.cos(ang), cy + rad * math.sin(ang)))
    draw.polygon(pts, fill=fill)


def draw_mark(size):
    """Cap + sparkles on a transparent canvas (coordinates for a 1024 grid)."""
    k = size / 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # base of the cap (under the board)
    d.rounded_rectangle(
        [352 * k, 500 * k, 672 * k, 668 * k], radius=70 * k, fill=LAVENDER
    )
    # board (diamond)
    cx, cy, w, h = 512 * k, 455 * k, 360 * k, 150 * k
    d.polygon(
        [(cx, cy - h), (cx + w, cy), (cx, cy + h), (cx - w, cy)], fill=WHITE
    )
    # tassel
    tx = cx + w * 0.62
    d.line([(tx, cy + 5 * k), (tx, 640 * k)], fill=GOLD, width=int(20 * k))
    d.ellipse(
        [tx - 30 * k, 640 * k - 30 * k, tx + 30 * k, 640 * k + 30 * k], fill=GOLD
    )
    # sparkles (AI)
    star(d, 770 * k, 270 * k, 95 * k, WHITE)
    star(d, 885 * k, 395 * k, 42 * k, (255, 255, 255, 200))
    star(d, 668 * k, 210 * k, 30 * k, (255, 255, 255, 170))
    return img


def full_logo(size=512):
    big = S
    grad = diagonal_gradient(big, VIOLET, BLUE).convert("RGBA")

    # soft top-left highlight
    glow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-big * 0.1, -big * 0.15, big * 0.75, big * 0.65], fill=(255, 255, 255, 60))
    glow = glow.filter(ImageFilter.GaussianBlur(big * 0.08))
    grad = Image.alpha_composite(grad, glow)

    # disc mask
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).ellipse([big * 0.02, big * 0.02, big * 0.98, big * 0.98], fill=255)
    disc = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    disc.paste(grad, (0, 0), mask)

    # thin light ring
    ring = ImageDraw.Draw(disc)
    ring.ellipse(
        [big * 0.045, big * 0.045, big * 0.955, big * 0.955],
        outline=(255, 255, 255, 70),
        width=int(big * 0.006),
    )

    mark = draw_mark(big)
    # soft shadow under the mark
    shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    shadow.paste((20, 10, 70, 110), (0, int(big * 0.012)), mark.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(big * 0.012))
    out = Image.alpha_composite(disc, shadow)
    out = Image.alpha_composite(out, mark)
    return out.resize((size, size), Image.LANCZOS)


def foreground(size):
    """Mark scaled into the adaptive-icon safe zone (inner ~60%)."""
    big = draw_mark(S)
    inner = int(size * 0.62)
    mark = big.resize((inner, inner), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    off = (size - inner) // 2
    canvas.paste(mark, (off, off), mark)
    return canvas


def main():
    os.makedirs("assets/branding", exist_ok=True)
    logo = full_logo(512)
    logo.save("assets/branding/logo.png")
    foreground(1024).save("assets/branding/logo_foreground.png")

    res = "android/app/src/main/res"
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    full = full_logo(1024)
    for dens, px in legacy.items():
        d = f"{res}/mipmap-{dens}"
        os.makedirs(d, exist_ok=True)
        full.resize((px, px), Image.LANCZOS).save(f"{d}/ic_launcher.png")
    for dens, px in adaptive.items():
        foreground(px * 4).resize((px, px), Image.LANCZOS).save(
            f"{res}/mipmap-{dens}/ic_launcher_foreground.png"
        )

    os.makedirs(f"{res}/drawable", exist_ok=True)
    with open(f"{res}/drawable/ic_launcher_background.xml", "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<shape xmlns:android="http://schemas.android.com/apk/res/android" '
            'android:shape="rectangle">\n'
            '    <gradient android:angle="315" android:startColor="#8B5CFF" '
            'android:endColor="#2979FF" android:type="linear" />\n'
            "</shape>\n"
        )
    os.makedirs(f"{res}/mipmap-anydpi-v26", exist_ok=True)
    with open(f"{res}/mipmap-anydpi-v26/ic_launcher.xml", "w", encoding="utf-8") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@drawable/ic_launcher_background" />\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
            "</adaptive-icon>\n"
        )
    print("logo, adaptive ve legacy launcher ikonları üretildi")


if __name__ == "__main__":
    main()
