#!/usr/bin/env python3
"""Generate a professional app icon using Pillow."""

import os
import math

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    import subprocess
    subprocess.check_call(["pip3", "install", "Pillow", "-i", "https://pypi.tuna.tsinghua.edu.cn/simple", "-q"])
    from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "HealthAnalyzerApp", "Assets.xcassets", "AppIcon.appiconset")


def lerp_color(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def draw_gradient(draw, w, h, c1, c2):
    for y in range(h):
        t = y / h
        color = lerp_color(c1, c2, t)
        draw.line([(0, y), (w, y)], fill=color)


def draw_ecg_line(draw, cx, cy, scale, color, width):
    """Draw an ECG waveform centered at (cx, cy)."""
    points = []
    total_w = 600 * scale

    segments = [
        (0, 0), (60, 0), (80, -15), (100, 0),
        (140, 0), (160, -30), (175, 120), (190, -80),
        (205, 30), (220, 0), (260, 0),
        (280, -20), (310, -25), (340, 0),
        (380, 0), (400, -15), (420, 0),
        (460, 0), (480, -30), (495, 100), (510, -60),
        (525, 25), (540, 0), (600, 0),
    ]

    x_offset = cx - total_w / 2
    for sx, sy in segments:
        px = x_offset + sx * scale
        py = cy - sy * scale
        points.append((px, py))

    for i in range(len(points) - 1):
        draw.line([points[i], points[i + 1]], fill=color, width=width)


def draw_trend_line(draw, cx, cy, scale, color, width):
    """Draw a subtle upward trend line."""
    points = []
    total_w = 500 * scale
    x_start = cx - total_w / 2
    steps = 20

    for i in range(steps + 1):
        t = i / steps
        x = x_start + t * total_w
        base_y = cy + 80 * scale - t * 160 * scale
        wave = math.sin(t * math.pi * 3) * 15 * scale
        points.append((x, base_y + wave))

    for i in range(len(points) - 1):
        draw.line([points[i], points[i + 1]], fill=color, width=width)


def draw_heart(draw, cx, cy, size, color):
    """Draw a simplified heart shape."""
    pts = []
    for i in range(360):
        t = math.radians(i)
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cx + x * size / 16, cy + y * size / 16))
    draw.polygon(pts, fill=color)


def generate():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Background gradient: deep blue to cyan
    blue_start = (10, 100, 220)
    blue_end = (30, 180, 240)
    draw_gradient(draw, SIZE, SIZE, blue_start, blue_end)

    # Subtle radial glow in center
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    for r in range(300, 0, -2):
        alpha = int(25 * (1 - r / 300))
        glow_draw.ellipse(
            [SIZE // 2 - r, SIZE // 2 - r - 50, SIZE // 2 + r, SIZE // 2 + r - 50],
            fill=(255, 255, 255, alpha)
        )
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # Trend line (subtle, behind ECG)
    trend_color = (255, 255, 255, 80)
    trend_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    trend_draw = ImageDraw.Draw(trend_img)
    draw_trend_line(trend_draw, SIZE // 2, SIZE // 2 + 40, 1.2, (255, 255, 255, 60), 4)
    img = Image.alpha_composite(img, trend_img)
    draw = ImageDraw.Draw(img)

    # ECG waveform (white, prominent)
    ecg_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ecg_draw = ImageDraw.Draw(ecg_img)
    draw_ecg_line(ecg_draw, SIZE // 2, SIZE // 2 - 20, 1.3, (255, 255, 255, 230), 7)
    ecg_blur = ecg_img.filter(ImageFilter.GaussianBlur(2))
    img = Image.alpha_composite(img, ecg_blur)
    draw_ecg_line(ImageDraw.Draw(img), SIZE // 2, SIZE // 2 - 20, 1.3, (255, 255, 255, 255), 5)

    # Small heart icon top-center
    heart_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    heart_draw = ImageDraw.Draw(heart_img)
    draw_heart(heart_draw, SIZE // 2, SIZE // 4 + 30, 28, (255, 80, 80, 200))
    heart_blur = heart_img.filter(ImageFilter.GaussianBlur(1))
    img = Image.alpha_composite(img, heart_blur)

    # Three small dots at bottom (like Apple Health)
    dot_y = SIZE - SIZE // 5
    for i, dx in enumerate([-40, 0, 40]):
        alpha = 160 if i == 1 else 90
        dot_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        ddraw = ImageDraw.Draw(dot_img)
        ddraw.ellipse(
            [SIZE // 2 + dx - 6, dot_y - 6, SIZE // 2 + dx + 6, dot_y + 6],
            fill=(255, 255, 255, alpha)
        )
        img = Image.alpha_composite(img, dot_img)

    # Convert to RGB (iOS icons don't have alpha)
    final = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    final.paste(img, mask=img.split()[3])

    os.makedirs(OUT_DIR, exist_ok=True)
    out_path = os.path.join(OUT_DIR, "AppIcon.png")
    final.save(out_path, "PNG")
    print(f"✓ Icon saved to: {out_path}")
    print(f"  Size: {os.path.getsize(out_path)} bytes")

    import json
    contents = {
        "images": [
            {"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(OUT_DIR, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print("✓ Contents.json updated")


if __name__ == "__main__":
    generate()
