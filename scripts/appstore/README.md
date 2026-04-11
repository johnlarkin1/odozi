# App Store screenshot generators

Python scripts that build the visual assets used in Odyssey's App Store
screenshot filmstrip: a continuous cosmic nebula background split into
per-slide tiles, and framed iPhone mockups (flat + 3D-tilted) that get
composited on top in Penpot.

## What's here

| Script | Purpose |
|---|---|
| `gen_panorama.py` | Builds the 5-slide continuous nebula and slices it into `slide_bg_1..5.png` |
| `gen_slide_bg_6.py` | Extends the nebula rightward by one slide (gold → coral sunset) — leaves slides 1–5 pixel-identical |
| `gen_phone_frames.py` | Wraps the real Odyssey screenshots in a dark bezel + cosmic glow + drop shadow, producing flat + `tiltL` + `tiltR` variants |

## Inputs

- Real app screenshots live in `website/public/screenshots/` — these are the
  same production-quality captures the marketing site uses.
- Filenames the scripts expect: `today-tab.png`, `guided-journaling.png`,
  `insights-dashboard.png`, `map-visualization.png`, `year-in-review.png`,
  `word-cloud.png`.

## Outputs

- Background slices → `designs/appstore/backgrounds/` (committed)
  - `slide_bg_1.png … slide_bg_6.png` — 1284×2778, iPhone 6.7"
  - `panorama_5.png` — full 6420×2778 panorama
  - `panorama_5_preview.png` — scaled-down reference
- Framed phones → `appstore-assets/framed-phones/` (gitignored, regenerate on demand)
  - `framed_<slug>.png`, `framed_<slug>_tiltL.png`, `framed_<slug>_tiltR.png`

## Usage

From the repo root:

```bash
# Backgrounds (5-slide base)
python3 scripts/appstore/gen_panorama.py

# Add the 6th slide — leaves slides 1-5 untouched
python3 scripts/appstore/gen_slide_bg_6.py

# Framed phones (flat + two 3D tilt variants each)
python3 scripts/appstore/gen_phone_frames.py
```

Requires Pillow and numpy:

```bash
pip install Pillow numpy
```

## Design notes

- Panorama width is `1284 × N` so every slice aligns with the iPhone 6.7"
  App Store Connect dimensions (1284×2778). Glow pockets are positioned as
  fractions of panorama width so each slide gets its own color region with
  no hard seams at the boundaries.
- `gen_slide_bg_6.py` rescales every existing glow's X fraction by 5/6 so
  its absolute pixel position stays identical when the canvas widens from
  5 × 1284 to 6 × 1284. Star positions are re-randomized (seed 23) over the
  wider canvas, but only slide 6 is written to disk so slides 1–5 stay
  pixel-identical.
- Phone framing in `gen_phone_frames.py` combines a mild perspective warp
  (~7% edge-length difference) with an ~18° in-plane rotation. That matches
  the "casually tilted in someone's hand" look from modern App Store pages
  without making screen content unreadable.

## How these flow into the App Store submission

1. Run `gen_panorama.py` + `gen_slide_bg_6.py` → committed background tiles.
2. Run `gen_phone_frames.py` → ephemeral framed phone PNGs.
3. In Penpot, drop the backgrounds into 6 frames (one per slide) and overlay
   the framed phones, alternating `tiltL` / `tiltR` for rhythm. Let phones
   bleed across frame boundaries — turn off *Clip content* on each frame.
4. Export from Penpot as 1284×2778 PNGs, drop into
   `screenshots/en-US/` per fastlane naming convention, and submit via
   `scripts/appstore-assets.sh`.
