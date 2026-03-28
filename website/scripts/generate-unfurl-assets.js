#!/usr/bin/env node

/**
 * Generate unfurl assets from screen recordings.
 *
 * Prerequisites:
 *   brew install ffmpeg
 *
 * Inputs (place in public/unfurls/):
 *   main_input.mov  — 3-5 sec screen recording at 2400x1260 (Retina 2x)
 *   main_input.png  — static screenshot at 2400x1260
 *
 * Outputs (all 1200x630):
 *   main.mp4         — h.264, yuv420p, faststart (iMessage og:video)
 *   main.gif         — two-pass palette GIF, 15fps (Discord, Slack, LinkedIn)
 *   main-static.png  — lanczos downscale (Twitter, Facebook, WhatsApp)
 *   main-static.jpg  — JPEG variant
 *   main-static.webp — WebP variant
 */

import { execFileSync } from "child_process";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const UNFURLS_DIR = path.join(__dirname, "..", "public", "unfurls");

const INPUTS = {
  mov: path.join(UNFURLS_DIR, "main_input.mov"),
  movFast: path.join(UNFURLS_DIR, "main_input_fast.mov"),
  png: path.join(UNFURLS_DIR, "main_input.png"),
};

const OUTPUTS = {
  mp4: path.join(UNFURLS_DIR, "main.mp4"),
  gif: path.join(UNFURLS_DIR, "main.gif"),
  png: path.join(UNFURLS_DIR, "main-static.png"),
  jpg: path.join(UNFURLS_DIR, "main-static.jpg"),
  webp: path.join(UNFURLS_DIR, "main-static.webp"),
};

const PALETTE_PATH = "/tmp/odyssey-unfurl-palette.png";
const SDR_INTERMEDIATE = "/tmp/odyssey-unfurl-sdr.mp4";

function run(cmd, args, label) {
  console.log(`\n--- ${label} ---`);
  console.log(`  $ ${cmd} ${args.join(" ")}\n`);
  try {
    execFileSync(cmd, args, { stdio: "inherit" });
    console.log(`  Done.`);
  } catch (e) {
    console.error(`  FAILED: ${e.message}`);
    process.exit(1);
  }
}

function runFfmpeg(args, label) {
  run("ffmpeg", args, label);
}

function checkPrerequisites() {
  try {
    execFileSync("ffmpeg", ["-version"], { stdio: "pipe" });
  } catch {
    console.error("Error: ffmpeg is not installed. Run: brew install ffmpeg");
    process.exit(1);
  }

  try {
    execFileSync("which", ["avconvert"], { stdio: "pipe" });
  } catch {
    console.error("Error: avconvert not found. This script requires macOS.");
    process.exit(1);
  }

  if (!fs.existsSync(UNFURLS_DIR)) {
    fs.mkdirSync(UNFURLS_DIR, { recursive: true });
  }
}

function generateFromMov() {
  if (!fs.existsSync(INPUTS.mov)) {
    console.log(
      `Skipping video assets — ${path.basename(INPUTS.mov)} not found.`,
    );
    console.log(
      "  Record the canvas at localhost:3000/unfurl and save as main_input.mov",
    );
    return;
  }

  // Saturation boost (1.4) + slight contrast bump (1.05) recovers vibrancy
  // lost in the HDR→SDR conversion. Applied to both MP4 and GIF.
  const colorBoost = "eq=saturation=1.4:contrast=1.05";

  // MP4: HDR→SDR via avconvert, then color-boost. Uses main_input.mov.
  run("avconvert",
    ["--source", INPUTS.mov, "--output", SDR_INTERMEDIATE, "--preset", "Preset1920x1080", "--replace"],
    "MOV -> SDR intermediate (avconvert)",
  );

  runFfmpeg(
    [
      "-y", "-i", SDR_INTERMEDIATE,
      "-c:v", "libx264", "-preset", "slow", "-crf", "18",
      "-pix_fmt", "yuv420p", "-movflags", "+faststart",
      "-vf", `${colorBoost},scale=1200:630:flags=lanczos`,
      "-an", OUTPUTS.mp4,
    ],
    "SDR -> MP4 (color-boosted)",
  );

  // GIF: Uses main_input_fast.mov (shorter, faster boat) for smaller file size.
  const gifSource = fs.existsSync(INPUTS.movFast) ? INPUTS.movFast : INPUTS.mov;
  const gifSourceName = path.basename(gifSource);
  console.log(`\n  GIF source: ${gifSourceName}`);

  const SDR_GIF_INTERMEDIATE = "/tmp/odyssey-unfurl-sdr-gif.mp4";
  run("avconvert",
    ["--source", gifSource, "--output", SDR_GIF_INTERMEDIATE, "--preset", "Preset1920x1080", "--replace"],
    `${gifSourceName} -> SDR intermediate (avconvert)`,
  );

  runFfmpeg(
    [
      "-y", "-i", SDR_GIF_INTERMEDIATE,
      "-vf", `${colorBoost},fps=24,scale=1200:630:flags=lanczos,palettegen=max_colors=256:stats_mode=diff`,
      PALETTE_PATH,
    ],
    "GIF Pass 1: Generate palette (color-boosted)",
  );

  runFfmpeg(
    [
      "-y", "-i", SDR_GIF_INTERMEDIATE, "-i", PALETTE_PATH,
      "-lavfi", `${colorBoost},fps=24,scale=1200:630:flags=lanczos[x];[x][1:v]paletteuse=dither=sierra2_4a:diff_mode=rectangle`,
      OUTPUTS.gif,
    ],
    "GIF Pass 2: Apply palette",
  );

  // Clean up intermediates
  for (const f of [PALETTE_PATH, SDR_INTERMEDIATE, SDR_GIF_INTERMEDIATE]) {
    if (fs.existsSync(f)) fs.unlinkSync(f);
  }
}

function generateFromPng() {
  if (!fs.existsSync(INPUTS.png)) {
    console.log(
      `Skipping static assets — ${path.basename(INPUTS.png)} not found.`,
    );
    console.log(
      "  Take a screenshot of the canvas at localhost:3000/unfurl and save as main_input.png",
    );
    return;
  }

  // PNG -> PNG (downscale 2400x1260 -> 1200x630)
  runFfmpeg(
    ["-y", "-i", INPUTS.png, "-vf", "scale=1200:630:flags=lanczos", OUTPUTS.png],
    "PNG -> PNG (downscale)",
  );

  // PNG -> JPG
  runFfmpeg(
    ["-y", "-i", OUTPUTS.png, "-q:v", "2", OUTPUTS.jpg],
    "PNG -> JPG",
  );

  // PNG -> WebP
  runFfmpeg(
    ["-y", "-i", OUTPUTS.png, "-quality", "90", OUTPUTS.webp],
    "PNG -> WebP",
  );
}

function printSummary() {
  console.log("\n=== Asset Summary ===\n");
  for (const [label, filePath] of Object.entries(OUTPUTS)) {
    if (fs.existsSync(filePath)) {
      const stats = fs.statSync(filePath);
      const sizeKB = (stats.size / 1024).toFixed(1);
      console.log(`  ${label.padEnd(6)} ${path.basename(filePath).padEnd(22)} ${sizeKB} KB`);
    } else {
      console.log(`  ${label.padEnd(6)} (not generated)`);
    }
  }
  console.log("");
}

// --- Main ---
checkPrerequisites();
generateFromMov();
generateFromPng();
printSummary();
