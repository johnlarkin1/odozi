"""Generate the 5-slide continuous cosmic nebula panorama for the App Store
screenshot filmstrip.

Produces a single 6420x2778 image and slices it into five 1284x2778
iPhone 6.7" frames whose edges flow seamlessly across the filmstrip.

Outputs → designs/appstore/backgrounds/:
  panorama_5.png                 full panorama (6420x2778)
  slide_bg_1.png … slide_bg_5.png single-slide slices
  panorama_5_preview.png         1/5-scale preview for quick visual checks

Run from the repo root:
  python3 scripts/appstore/gen_panorama.py

Requires: Pillow.
"""
from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

REPO_ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = REPO_ROOT / "designs" / "appstore" / "backgrounds"
OUT_DIR.mkdir(parents=True, exist_ok=True)

W, H = 1284, 2778
N = 5
PW = W * N

DEEP_SPACE = (13, 13, 31)
COSMIC_PURPLE = (140, 92, 245)
NEBULA_PINK = (232, 107, 173)
ACCENT_TEAL = (46, 196, 182)
ACCENT_AMBER = (245, 166, 35)
STAR_WHITE = (237, 240, 250)


def radial_glow(size, center, radius, color, max_opacity):
    w, h = size
    scale = 10
    sw, sh = max(1, w // scale), max(1, h // scale)
    cx, cy = center[0] / scale, center[1] / scale
    sr = radius / scale
    mask = Image.new("L", (sw, sh), 0)
    d = ImageDraw.Draw(mask)
    steps = 48
    for i in range(steps, 0, -1):
        t = i / steps
        r = sr * t
        alpha = int(255 * max_opacity * (1 - t) ** 2.2)
        if r > 0:
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=alpha)
    mask = mask.filter(ImageFilter.GaussianBlur(radius=sr * 0.35))
    mask = mask.resize((w, h), Image.LANCZOS)
    layer = Image.new("RGBA", (w, h), color + (0,))
    solid = Image.new("RGBA", (w, h), color + (255,))
    layer.paste(solid, (0, 0), mask)
    return layer


def draw_stars(size, count, seed):
    w, h = size
    rng = random.Random(seed)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(count):
        x = rng.randint(0, w - 1)
        y = rng.randint(0, h - 1)
        kind = rng.random()
        if kind < 0.70:
            r = rng.choice([1, 1, 2])
            a = rng.randint(90, 180)
            d.ellipse((x - r, y - r, x + r, y + r), fill=(*STAR_WHITE, a))
        elif kind < 0.93:
            r = rng.choice([2, 3])
            a = rng.randint(170, 230)
            d.ellipse((x - r, y - r, x + r, y + r), fill=(*STAR_WHITE, a))
        else:
            r = rng.choice([3, 4])
            d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, 240))
            halo_r = r * 7
            halo = Image.new("RGBA", (halo_r * 2, halo_r * 2), (0, 0, 0, 0))
            hd = ImageDraw.Draw(halo)
            for i in range(halo_r, 0, -1):
                alpha = int(70 * (1 - i / halo_r) ** 2)
                hd.ellipse((halo_r - i, halo_r - i, halo_r + i, halo_r + i),
                           fill=(*STAR_WHITE, alpha))
            halo = halo.filter(ImageFilter.GaussianBlur(radius=halo_r * 0.45))
            layer.alpha_composite(halo, (x - halo_r, y - halo_r))
    return layer


def build_panorama():
    """One continuous 6420x2778 nebula. Glow pockets are placed so each slide
    gets its own color region without hard seams between slides."""
    size = (PW, H)
    img = Image.new("RGBA", size, DEEP_SPACE + (255,))

    # Big central purple heart — the whole panorama's main glow
    img.alpha_composite(radial_glow(size, (PW * 0.50, H * 0.35),
                                    max(size) * 0.55, COSMIC_PURPLE, 0.95))
    img.alpha_composite(radial_glow(size, (PW * 0.48, H * 0.45),
                                    max(size) * 0.85, COSMIC_PURPLE, 0.55))

    # Slide 1 — teal cool accent
    img.alpha_composite(radial_glow(size, (PW * 0.08, H * 0.30),
                                    max(size) * 0.32, ACCENT_TEAL, 0.55))
    img.alpha_composite(radial_glow(size, (PW * 0.12, H * 0.65),
                                    max(size) * 0.25, COSMIC_PURPLE, 0.65))

    # Slide 2 — purple hot spot
    img.alpha_composite(radial_glow(size, (PW * 0.30, H * 0.50),
                                    max(size) * 0.30, COSMIC_PURPLE, 0.80))
    img.alpha_composite(radial_glow(size, (PW * 0.28, H * 0.72),
                                    max(size) * 0.22, (168, 72, 200), 0.60))

    # Slide 3 — core purple (already strong from the main heart)
    img.alpha_composite(radial_glow(size, (PW * 0.50, H * 0.60),
                                    max(size) * 0.28, NEBULA_PINK, 0.45))

    # Slide 4 — magenta / pink hot spot
    img.alpha_composite(radial_glow(size, (PW * 0.72, H * 0.40),
                                    max(size) * 0.32, NEBULA_PINK, 0.75))
    img.alpha_composite(radial_glow(size, (PW * 0.75, H * 0.65),
                                    max(size) * 0.25, COSMIC_PURPLE, 0.55))

    # Slide 5 — warm amber pocket
    img.alpha_composite(radial_glow(size, (PW * 0.93, H * 0.35),
                                    max(size) * 0.34, ACCENT_AMBER, 0.60))
    img.alpha_composite(radial_glow(size, (PW * 0.90, H * 0.65),
                                    max(size) * 0.26, NEBULA_PINK, 0.40))

    # Deepen the bottom so CTAs/headlines stay readable when placed there
    img.alpha_composite(radial_glow(size, (PW * 0.5, H * 1.08),
                                    max(size) * 0.70, (3, 3, 10), 0.85))

    # Stars across the whole panorama
    img.alpha_composite(draw_stars(size, count=900, seed=23))

    # Subtle top/bottom vignette
    vg = Image.new("RGBA", size, (0, 0, 0, 0))
    vd = ImageDraw.Draw(vg)
    for y in range(H):
        t = abs(y - H / 2) / (H / 2)
        alpha = int(85 * (t ** 2.4))
        vd.line([(0, y), (PW, y)], fill=(0, 0, 0, alpha))
    img.alpha_composite(vg)

    return img


def main():
    print("building 5-slide panorama...")
    pan = build_panorama()
    print(f"  size: {pan.size}")

    full = OUT_DIR / "panorama_5.png"
    pan.convert("RGB").save(full, "PNG", optimize=True)
    print(f"  wrote {full.relative_to(REPO_ROOT)} ({full.stat().st_size // 1024} KB)")

    for i in range(N):
        slice_img = pan.crop((i * W, 0, (i + 1) * W, H)).convert("RGB")
        path = OUT_DIR / f"slide_bg_{i + 1}.png"
        slice_img.save(path, "PNG", optimize=True)
        print(f"  wrote {path.relative_to(REPO_ROOT)} ({path.stat().st_size // 1024} KB)")

    preview_path = OUT_DIR / "panorama_5_preview.png"
    pan.resize((pan.width // 5, pan.height // 5),
               Image.LANCZOS).convert("RGB").save(preview_path, "PNG", optimize=True)
    print(f"  wrote {preview_path.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
