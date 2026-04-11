# SampleAssets

Per-day fake content used by `SampleData` when Odyssey runs in DEBUG +
`SCREENSHOT_MODE=1`. Lets you pin real photos + personalized journal text +
custom moods to specific days in the sample data, without editing Swift code.

**Privacy**: the `day_NN/photo.*`, `journal.txt`, and `mood.txt` files inside
each subfolder are gitignored. `SampleData` loads them from disk at runtime via
`#filePath`, so they are **not** bundled into the shipped App Store binary.
Only the subfolder scaffolding (`.gitkeep`) is tracked in git.

## How the days map to the sample data

The seeded data runs 30 days back from today. Each `day_NN` folder corresponds
to `daysAgo = NN`, so `day_01` is yesterday and `day_30` would be 30 days ago.

Seven days have photo slots by default:

| Folder | `daysAgo` | Type | Default journal text (overridable) |
|---|---|---|---|
| `day_01/` | 1 (yesterday) | 🐕 dog | "Saw a cute dog today. Little corgi in Central Park…" |
| `day_05/` | 5 | 🌇 sunset | "Sunset from the rooftop was unreal…" |
| `day_07/` | 7 | 🐕 dog | "Puppy at the coffee shop kept staring at my croissant…" |
| `day_12/` | 12 | 🍃 park | "Quiet Sunday in Prospect Park…" |
| `day_15/` | 15 | 🐕 dog | "Saw a cute dog today in the East Village…" |
| `day_23/` | 23 | 🐕 dog | "Saw the cutest golden retriever on the High Line…" |
| `day_28/` | 28 | 🐕 dog | "Cute dachshund in Washington Square, wearing a tiny jacket…" |

## What to put in each folder

Each `day_NN/` folder accepts up to three files — all optional.

### `photo.*` — the attached photo

Used as the map-pin thumbnail **and** the detail-card attachment on that day.

- Accepted extensions: `.jpg`, `.jpeg`, `.png`, `.heic` (case-insensitive)
- Landscape or square crops read best in the 80×80 map-pin thumbnail
- Any resolution up to several MB is fine — `SampleData` resizes on load
  (max 1200 px for the full-size version, 200 px for the thumbnail)
- If no `photo.*` is present, the app falls back to a procedural gradient +
  SF Symbol thumbnail for that day

### `journal.txt` — override the default journal entry

Plain UTF-8 text, single line or multi-line. Overrides the hardcoded journal
for that day so you can write something personal:

```
Last walk with Buddy at Central Park. He went straight for the squirrels
like he always did. Stopped to let a kid pet him. Best dog I'll ever know.
```

If the file is missing or empty, the hardcoded text in `SampleData.swift` is
used instead.

### `mood.txt` — override the mood score

Single integer from 1 to 10, e.g.:

```
9
```

Dog days default to mood `8`; setting this lets you bump a specific day up or
down. Any value outside `1...10` is ignored.

## Typical workflow

1. Drop your dog's photo into `day_01/photo.jpg`
2. Optionally write a memory into `day_01/journal.txt`
3. Optionally bump the mood in `day_01/mood.txt`
4. Build + run with `SCREENSHOT_MODE=1` in the scheme's environment variables
5. Navigate to the Journey tab — your dog's photo shows on the map pin in NYC,
   the detail card has the attached photo and your journal text
6. Capture the screenshot with `xcrun simctl io booted screenshot <path>`

The same photo works in all five dog days if you want a consistent cluster —
just copy `photo.jpg` into each `day_NN/` folder.
