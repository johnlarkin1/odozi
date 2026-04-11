"""Wrap each real Odyssey screenshot in an iPhone-style frame, in two variants
— flat and 3D-tilted — ready to drop into a Penpot / Figma App Store layout.

Per source screenshot (all transparent PNGs):
  framed_<slug>.png         Flat, straight-on, centered
  framed_<slug>_tiltL.png   Tilted counter-clockwise, right edge closer
  framed_<slug>_tiltR.png   Tilted clockwise, left edge closer

Each PNG has transparent background, built-in cosmic-purple glow + drop shadow,
and generous padding so the tilted versions don't crop.

Inputs:  website/public/screenshots/*.png   (committed to the repo)
Outputs: appstore-assets/framed-phones/     (gitignored — regenerate on demand)

Run from the repo root:
  python3 scripts/appstore/gen_phone_frames.py

Requires: Pillow, numpy.
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO_ROOT = Path(__file__).resolve().parents[2]
IN_DIR = REPO_ROOT / "website" / "public" / "screenshots"
OUT_DIR = REPO_ROOT / "appstore-assets" / "framed-phones"
OUT_DIR.mkdir(parents=True, exist_ok=True)

COSMIC_PURPLE = (140, 92, 245)

SCREENSHOTS = {
    "today-tab.png":          "today",
    "guided-journaling.png":  "guided",
    "insights-dashboard.png": "insights",
    "map-visualization.png":  "map",
    "year-in-review.png":     "year",
    "word-cloud.png":         "wordcloud",
}


# ─────────────────────────────────────────────────────────── frame primitives
def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255,
    )
    return m


def build_device(screen: Image.Image) -> Image.Image:
    """Return a transparent PNG of just the phone (bezel + screen), no shadow."""
    sw, sh = screen.size
    bezel = int(sw * 0.035)
    outer_radius = int(sw * 0.17)
    inner_radius = int(sw * 0.15)

    body_w = sw + bezel * 2
    body_h = sh + bezel * 2
    device = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))

    # body gradient
    body_fill = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))
    bf = ImageDraw.Draw(body_fill)
    for y in range(body_h):
        t = y / body_h
        r = int(18 + 4 * math.sin(t * math.pi))
        g = int(18 + 3 * math.sin(t * math.pi))
        b = int(26 + 6 * math.sin(t * math.pi))
        bf.line([(0, y), (body_w, y)], fill=(r, g, b, 255))
    body_mask = rounded_mask((body_w, body_h), radius=outer_radius)
    device.paste(body_fill, (0, 0), body_mask)

    # hairline border
    border = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle(
        (1, 1, body_w - 2, body_h - 2),
        radius=outer_radius, outline=(255, 255, 255, 45), width=3,
    )
    device.alpha_composite(border)

    # screen
    screen_mask = rounded_mask((sw, sh), radius=inner_radius)
    screen_clipped = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    screen_clipped.paste(screen, (0, 0), screen_mask)
    device.alpha_composite(screen_clipped, (bezel, bezel))

    return device


# ─────────────────────────────────────────────────────── perspective transform
def find_coeffs(src_corners, dst_corners):
    """Solve the 8 PIL perspective coefficients for dst → src sampling."""
    matrix = []
    for (sx, sy), (dx, dy) in zip(src_corners, dst_corners):
        matrix.append([dx, dy, 1, 0, 0, 0, -sx * dx, -sx * dy])
        matrix.append([0, 0, 0, dx, dy, 1, -sy * dx, -sy * dy])
    A = np.array(matrix, dtype=np.float64)
    B = np.array(src_corners).reshape(8)
    return np.linalg.solve(A, B).tolist()


def tilt(device: Image.Image, direction: str,
         lean: float = 0.18, z_rotate: float = 18.0) -> Image.Image:
    """Subtle 3D perspective plus a strong in-plane rotation.

    Replicates the look in modern App Store screenshots: phone clearly tilted
    like you rotated it in your hand (heavy Z rotation ~18°), with just enough
    Y-axis perspective (~7% edge-length difference) to feel dimensional rather
    than flat.

    direction: 'L' = counter-clockwise with right edge closer
               'R' = clockwise with left edge closer
    lean: 0..0.3 — Y-axis perspective intensity
    z_rotate: degrees — in-plane rotation (dominant effect)
    """
    w, h = device.size
    pad = int(max(w, h) * 0.20)
    cw, ch = w + pad * 2, h + pad * 2

    src = [
        (pad, pad),
        (pad + w, pad),
        (pad + w, pad + h),
        (pad, pad + h),
    ]

    if direction == "L":
        dst = [
            (pad + w * lean * 0.6, pad + h * lean * 0.35),
            (pad + w,              pad - h * lean * 0.15),
            (pad + w,              pad + h + h * lean * 0.15),
            (pad + w * lean * 0.6, pad + h - h * lean * 0.35),
        ]
        rot = -z_rotate
    else:
        dst = [
            (pad,                      pad - h * lean * 0.15),
            (pad + w - w * lean * 0.6, pad + h * lean * 0.35),
            (pad + w - w * lean * 0.6, pad + h - h * lean * 0.35),
            (pad,                      pad + h + h * lean * 0.15),
        ]
        rot = z_rotate

    coeffs = find_coeffs(src, dst)

    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    canvas.paste(device, (pad, pad))
    warped = canvas.transform((cw, ch), Image.PERSPECTIVE, coeffs,
                              resample=Image.BICUBIC)
    rotated = warped.rotate(rot, resample=Image.BICUBIC, expand=True,
                            fillcolor=(0, 0, 0, 0))
    return rotated


# ──────────────────────────────────────────────────────── shadow + glow layer
def add_glow_and_shadow(device: Image.Image,
                        glow_color=COSMIC_PURPLE) -> Image.Image:
    """Composite device on top of a cosmic glow + drop shadow.
    Returns a larger PNG with the transparent padding trimmed."""
    w, h = device.size
    pad = int(max(w, h) * 0.22)
    cw, ch = w + pad * 2, h + pad * 2
    canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))

    alpha = device.split()[-1]

    # cosmic glow — big blurred ellipse roughly matching the device
    glow = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = cw // 2, ch // 2
    for i in range(12, 0, -1):
        t = i / 12
        ew = int(w * (0.45 + t * 0.45))
        eh = int(h * (0.45 + t * 0.45))
        a = int(85 * (1 - t) ** 1.6)
        gd.ellipse((cx - ew // 2, cy - eh // 2, cx + ew // 2, cy + eh // 2),
                   fill=(*glow_color, a))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=pad * 0.55))
    canvas.alpha_composite(glow)

    # drop shadow built from device alpha
    shadow_shape = Image.new("L", (cw, ch), 0)
    shadow_shape.paste(alpha, (pad, pad + 50))
    shadow_shape = shadow_shape.filter(ImageFilter.GaussianBlur(radius=55))
    shadow_rgba = Image.merge("RGBA", (
        Image.new("L", (cw, ch), 0),
        Image.new("L", (cw, ch), 0),
        Image.new("L", (cw, ch), 0),
        shadow_shape.point(lambda p: int(p * 0.80)),
    ))
    canvas.alpha_composite(shadow_rgba)

    canvas.alpha_composite(device, (pad, pad))

    # trim empty transparent padding with a small margin so the glow survives
    bbox = canvas.getbbox()
    if bbox:
        margin = 20
        x0 = max(0, bbox[0] - margin)
        y0 = max(0, bbox[1] - margin)
        x1 = min(canvas.width, bbox[2] + margin)
        y1 = min(canvas.height, bbox[3] + margin)
        canvas = canvas.crop((x0, y0, x1, y1))
    return canvas


def main() -> None:
    for src_name, slug in SCREENSHOTS.items():
        src = IN_DIR / src_name
        if not src.exists():
            print(f"  skip (missing): {src.relative_to(REPO_ROOT)}")
            continue
        print(f"processing {src_name}")
        screen = Image.open(src).convert("RGBA")
        device = build_device(screen)

        for variant, img in (
            ("flat",  add_glow_and_shadow(device)),
            ("tiltL", add_glow_and_shadow(tilt(device, "L"))),
            ("tiltR", add_glow_and_shadow(tilt(device, "R"))),
        ):
            suffix = "" if variant == "flat" else f"_{variant}"
            out = OUT_DIR / f"framed_{slug}{suffix}.png"
            img.save(out, "PNG", optimize=True)
            print(f"  → {out.name} ({img.size}, {out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
