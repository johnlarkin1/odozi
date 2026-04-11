"""Generate a sixth nebula slice that extends the existing 5-wide panorama.

All existing glow X positions are kept at identical absolute pixel coordinates
(by rescaling their panorama-width fractions from /5 to /6), so
slide_bg_1..5.png are untouched and slide_bg_6.png flows off the right edge
of slide 5 without a visible seam. The new slide adds warm gold / coral
pockets and a purple wrap-back hint on the far right.

Run from the repo root:
  python3 scripts/appstore/gen_slide_bg_6.py

Requires: Pillow and gen_panorama.py (imported for the shared primitives).
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

from gen_panorama import (  # noqa: E402
    W, H, DEEP_SPACE, COSMIC_PURPLE, NEBULA_PINK, ACCENT_AMBER,
    radial_glow, draw_stars,
)

OUT_DIR = REPO_ROOT / "designs" / "appstore" / "backgrounds"
OUT_DIR.mkdir(parents=True, exist_ok=True)

N_OLD = 5
N_NEW = 6
PW_OLD = W * N_OLD   # 6420 — radii reference so slides 1..5 are pixel-identical
PW_NEW = W * N_NEW   # 7704
SCALE = N_OLD / N_NEW  # 5/6 — rescales old fractions to the wider canvas


def R(frac_of_old_pw: float) -> float:
    """Radius helper — preserves absolute pixel sizes from the 5-wide panorama."""
    return PW_OLD * frac_of_old_pw


def build() -> Image.Image:
    size = (PW_NEW, H)
    img = Image.new("RGBA", size, DEEP_SPACE + (255,))

    # ── Existing glows, rescaled so absolute X stays identical ──
    img.alpha_composite(radial_glow(size, (PW_NEW * 0.50 * SCALE, H * 0.35),
                                    R(0.55), COSMIC_PURPLE, 0.95))
    img.alpha_composite(radial_glow(size, (PW_NEW * 0.48 * SCALE, H * 0.45),
                                    R(0.85), COSMIC_PURPLE, 0.55))

    img.alpha_composite(radial_glow(size, (PW_NEW * 0.08 * SCALE, H * 0.30),
                                    R(0.32), (46, 196, 182), 0.55))
    img.alpha_composite(radial_glow(size, (PW_NEW * 0.12 * SCALE, H * 0.65),
                                    R(0.25), COSMIC_PURPLE, 0.65))

    img.alpha_composite(radial_glow(size, (PW_NEW * 0.30 * SCALE, H * 0.50),
                                    R(0.30), COSMIC_PURPLE, 0.80))
    img.alpha_composite(radial_glow(size, (PW_NEW * 0.28 * SCALE, H * 0.72),
                                    R(0.22), (168, 72, 200), 0.60))

    img.alpha_composite(radial_glow(size, (PW_NEW * 0.50 * SCALE, H * 0.60),
                                    R(0.28), NEBULA_PINK, 0.45))

    img.alpha_composite(radial_glow(size, (PW_NEW * 0.72 * SCALE, H * 0.40),
                                    R(0.32), NEBULA_PINK, 0.75))
    img.alpha_composite(radial_glow(size, (PW_NEW * 0.75 * SCALE, H * 0.65),
                                    R(0.25), COSMIC_PURPLE, 0.55))

    img.alpha_composite(radial_glow(size, (PW_NEW * 0.93 * SCALE, H * 0.35),
                                    R(0.34), ACCENT_AMBER, 0.60))
    img.alpha_composite(radial_glow(size, (PW_NEW * 0.90 * SCALE, H * 0.65),
                                    R(0.26), NEBULA_PINK, 0.40))

    # ── New slide 6 — warm gold → coral sunset with a purple wrap-back hint ──
    CORAL = (245, 110, 95)
    GOLD = (252, 192, 80)

    img.alpha_composite(radial_glow(size, (PW_NEW * 0.88, H * 0.32),
                                    R(0.34), GOLD, 0.70))
    img.alpha_composite(radial_glow(size, (PW_NEW * 0.93, H * 0.62),
                                    R(0.30), CORAL, 0.60))
    img.alpha_composite(radial_glow(size, (PW_NEW * 1.00, H * 0.45),
                                    R(0.22), COSMIC_PURPLE, 0.50))
    img.alpha_composite(radial_glow(size, (PW_NEW * 0.84, H * 0.55),
                                    R(0.18), NEBULA_PINK, 0.35))

    # Bottom vignette (shape matches the original)
    img.alpha_composite(radial_glow(size, (PW_NEW * 0.5 * SCALE, H * 1.08),
                                    R(0.70), (3, 3, 10), 0.85))

    # Stars — density scaled for the wider canvas
    star_count = int(900 * N_NEW / N_OLD)  # 1080
    img.alpha_composite(draw_stars(size, count=star_count, seed=23))

    # Top/bottom vignette
    vg = Image.new("RGBA", size, (0, 0, 0, 0))
    vd = ImageDraw.Draw(vg)
    for y in range(H):
        t = abs(y - H / 2) / (H / 2)
        alpha = int(85 * (t ** 2.4))
        vd.line([(0, y), (PW_NEW, y)], fill=(0, 0, 0, alpha))
    img.alpha_composite(vg)

    return img


def main() -> None:
    print("building 6-wide nebula (extracting slide 6 only)…")
    pan = build()
    print(f"  size: {pan.size}")

    slice6 = pan.crop((N_OLD * W, 0, N_NEW * W, H)).convert("RGB")
    out = OUT_DIR / "slide_bg_6.png"
    slice6.save(out, "PNG", optimize=True)
    print(f"  wrote {out.relative_to(REPO_ROOT)} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
