const { createCanvas } = require("canvas");
const GIFEncoder = require("gif-encoder-2");
const fs = require("fs");
const path = require("path");

const WIDTH = 1200;
const HEIGHT = 630;
const FRAMES = 48;
const DELAY = 70; // ~14fps, smooth looping

function lerp(a, b, t) { return a + (b - a) * t; }

function drawFrame(ctx, frame) {
  const t = frame / FRAMES; // 0..1 (loops)

  // Background - deep cosmic navy matching app icon
  const bgGrad = ctx.createLinearGradient(0, 0, 0, HEIGHT);
  bgGrad.addColorStop(0, "#0e0e2a");
  bgGrad.addColorStop(0.45, "#1a1645");
  bgGrad.addColorStop(0.65, "#1e1a4a");
  bgGrad.addColorStop(1, "#141035");
  ctx.fillStyle = bgGrad;
  ctx.fillRect(0, 0, WIDTH, HEIGHT);

  // Subtle purple glow behind boat area (like app icon)
  drawGlow(ctx, WIDTH * 0.5, HEIGHT * 0.35, 280, "rgba(120, 70, 200, 0.12)");
  drawGlow(ctx, WIDTH * 0.4, HEIGHT * 0.4, 200, "rgba(200, 100, 50, 0.06)");

  // Stars - lots of them, gentle twinkle
  drawStars(ctx, t);

  // Ocean
  const oceanTop = HEIGHT * 0.58;
  drawOcean(ctx, t, oceanTop);

  // Boat sailing across - smooth eased movement
  const eased = smoothStep(t);
  const boatX = lerp(-120, WIDTH + 120, eased);
  const bobPhase = t * Math.PI * 8;
  const boatY = oceanTop - 8 + Math.sin(bobPhase) * 2.5;
  const boatTilt = Math.sin(bobPhase) * 0.015;

  // Boat reflection on water
  drawBoatReflection(ctx, boatX, oceanTop + 5, boatTilt);

  // The boat itself - matching app icon style
  drawAppIconBoat(ctx, boatX, boatY, boatTilt);

  // Wake behind boat
  drawWake(ctx, boatX, oceanTop + 4, t, eased);

  // Title - "Odozi"
  drawTitle(ctx);
}

function smoothStep(t) {
  // Smooth ease-in-out for natural sailing feel
  return t * t * (3 - 2 * t);
}

function drawGlow(ctx, x, y, radius, color) {
  const grad = ctx.createRadialGradient(x, y, 0, x, y, radius);
  grad.addColorStop(0, color);
  grad.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = grad;
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.fill();
}

function drawStars(ctx, t) {
  // Seed-based star positions for consistency
  const stars = [];
  for (let i = 0; i < 60; i++) {
    const seed = i * 7919; // prime for spread
    const sx = (seed * 13) % WIDTH;
    const sy = (seed * 29) % (HEIGHT * 0.55); // only in sky area
    const size = 0.6 + (seed % 100) / 100;
    const phase = (seed % 314) / 100;
    stars.push([sx, sy, size, phase]);
  }

  stars.forEach(([x, y, size, phase]) => {
    const twinkle = 0.3 + 0.7 * (0.5 + 0.5 * Math.sin(t * Math.PI * 2 + phase));
    ctx.beginPath();
    ctx.arc(x, y, size, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(237, 240, 250, ${twinkle * 0.6})`;
    ctx.fill();
  });
}

function drawOcean(ctx, t, oceanTop) {
  // Deep ocean background matching app icon colors
  const waterGrad = ctx.createLinearGradient(0, oceanTop - 10, 0, HEIGHT);
  waterGrad.addColorStop(0, "#1a1854");
  waterGrad.addColorStop(0.2, "#1e1c5e");
  waterGrad.addColorStop(0.5, "#1a1850");
  waterGrad.addColorStop(1, "#141040");
  ctx.fillStyle = waterGrad;
  ctx.fillRect(0, oceanTop - 10, WIDTH, HEIGHT - oceanTop + 10);

  // Multiple wave layers for depth - matching app icon's wave style
  // Back waves (darker, slower)
  drawWaveLayer(ctx, t, oceanTop - 8, 12, 0.4, "#1e1a5a", 0.5, 0);
  drawWaveLayer(ctx, t, oceanTop - 2, 10, 0.5, "#222060", 0.45, 1.2);

  // Mid waves
  drawWaveLayer(ctx, t, oceanTop + 8, 8, 0.6, "#252268", 0.4, 2.5);
  drawWaveLayer(ctx, t, oceanTop + 18, 7, 0.7, "#282570", 0.35, 3.8);

  // Front waves (lighter, faster) - the purple-blue from app icon
  drawWaveLayer(ctx, t, oceanTop + 30, 6, 0.8, "#2e2878", 0.3, 5.0);
  drawWaveLayer(ctx, t, oceanTop + 42, 5, 0.9, "#322c80", 0.25, 6.2);

  // Subtle horizon glow
  const hGrad = ctx.createLinearGradient(0, oceanTop - 15, 0, oceanTop + 5);
  hGrad.addColorStop(0, "rgba(140, 92, 245, 0)");
  hGrad.addColorStop(0.5, "rgba(140, 92, 245, 0.08)");
  hGrad.addColorStop(1, "rgba(140, 92, 245, 0)");
  ctx.fillStyle = hGrad;
  ctx.fillRect(0, oceanTop - 15, WIDTH, 20);
}

function drawWaveLayer(ctx, t, baseY, amplitude, speed, color, alpha, offset) {
  ctx.beginPath();
  ctx.moveTo(0, HEIGHT);
  for (let x = 0; x <= WIDTH; x += 3) {
    const wave1 = Math.sin((x / WIDTH) * Math.PI * 2.5 + t * Math.PI * 2 * speed + offset) * amplitude;
    const wave2 = Math.sin((x / WIDTH) * Math.PI * 4 + t * Math.PI * 2 * speed * 0.7 + offset * 1.5) * amplitude * 0.3;
    ctx.lineTo(x, baseY + wave1 + wave2);
  }
  ctx.lineTo(WIDTH, HEIGHT);
  ctx.closePath();
  ctx.fillStyle = color;
  ctx.globalAlpha = alpha;
  ctx.fill();
  ctx.globalAlpha = 1;
}

function drawAppIconBoat(ctx, x, y, tilt) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(tilt);

  const scale = 1.1; // boat size

  // -- Hull: subtle dark shape at waterline --
  ctx.beginPath();
  ctx.moveTo(-28 * scale, 2 * scale);
  ctx.quadraticCurveTo(-20 * scale, 14 * scale, 0, 14 * scale);
  ctx.quadraticCurveTo(20 * scale, 14 * scale, 28 * scale, 2 * scale);
  ctx.closePath();
  ctx.fillStyle = "rgba(50, 40, 80, 0.6)";
  ctx.fill();

  // -- Mast: thin vertical line --
  ctx.beginPath();
  ctx.moveTo(0, 2 * scale);
  ctx.lineTo(0, -75 * scale);
  ctx.strokeStyle = "rgba(200, 160, 80, 0.7)";
  ctx.lineWidth = 1.8 * scale;
  ctx.stroke();

  // -- Main sail (left) - large triangle matching app icon --
  // The app icon has a big triangular sail with amber at top fading to purple at bottom
  ctx.beginPath();
  ctx.moveTo(0, -72 * scale);  // top of mast
  ctx.quadraticCurveTo(-32 * scale, -35 * scale, -26 * scale, 0); // left bulge
  ctx.lineTo(0, 0); // bottom of mast
  ctx.closePath();

  const sailLeftGrad = ctx.createLinearGradient(0, -72 * scale, 0, 0);
  sailLeftGrad.addColorStop(0, "#F5A623");    // amber top
  sailLeftGrad.addColorStop(0.3, "#E8922A");  // warm orange
  sailLeftGrad.addColorStop(0.6, "#D06838");  // orange-red
  sailLeftGrad.addColorStop(0.85, "#A04888"); // pink-purple
  sailLeftGrad.addColorStop(1, "#7C3FA0");    // purple bottom
  ctx.fillStyle = sailLeftGrad;
  ctx.fill();

  // -- Main sail (right) - slightly lighter --
  ctx.beginPath();
  ctx.moveTo(0, -72 * scale);  // top of mast
  ctx.quadraticCurveTo(30 * scale, -35 * scale, 24 * scale, 0); // right bulge
  ctx.lineTo(0, 0); // bottom of mast
  ctx.closePath();

  const sailRightGrad = ctx.createLinearGradient(0, -72 * scale, 0, 0);
  sailRightGrad.addColorStop(0, "#F5B030");   // slightly lighter amber
  sailRightGrad.addColorStop(0.3, "#EB9832");
  sailRightGrad.addColorStop(0.6, "#CC6040");
  sailRightGrad.addColorStop(0.85, "#9A4590");
  sailRightGrad.addColorStop(1, "#7038A0");
  ctx.fillStyle = sailRightGrad;
  ctx.fill();

  // -- Subtle sail glow --
  drawGlow(ctx, 0, -30 * scale, 50 * scale, "rgba(245, 166, 35, 0.08)");

  ctx.restore();
}

function drawBoatReflection(ctx, x, y, tilt) {
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(1, -0.3); // flip and squash
  ctx.rotate(-tilt);
  ctx.globalAlpha = 0.15;

  const scale = 1.1;

  // Reflected sail shape - simplified
  ctx.beginPath();
  ctx.moveTo(0, -72 * scale);
  ctx.quadraticCurveTo(-28 * scale, -35 * scale, -22 * scale, 0);
  ctx.lineTo(0, 0);
  ctx.quadraticCurveTo(26 * scale, -35 * scale, 0, -72 * scale);
  ctx.closePath();

  const reflGrad = ctx.createLinearGradient(0, -72 * scale, 0, 0);
  reflGrad.addColorStop(0, "#F5A623");
  reflGrad.addColorStop(1, "#7C3FA0");
  ctx.fillStyle = reflGrad;
  ctx.fill();

  ctx.globalAlpha = 1;
  ctx.restore();
}

function drawWake(ctx, boatX, wakeY, t, eased) {
  // Only draw wake if boat is on screen
  if (boatX < 0 || boatX > WIDTH) return;

  // V-shaped wake spreading behind the boat
  const wakeLen = Math.min(boatX, 200);

  for (let i = 0; i < 3; i++) {
    const spread = (i + 1) * 4;
    const len = wakeLen * (1 - i * 0.25);
    const alpha = 0.08 - i * 0.02;
    const wobble = Math.sin(t * Math.PI * 6 + i) * 1.5;

    // Upper wake line
    ctx.beginPath();
    ctx.moveTo(boatX - 25, wakeY + wobble);
    ctx.quadraticCurveTo(
      boatX - len * 0.5, wakeY - spread + wobble,
      boatX - len, wakeY - spread * 1.5 + wobble
    );
    ctx.strokeStyle = `rgba(200, 180, 240, ${alpha})`;
    ctx.lineWidth = 1.2 - i * 0.3;
    ctx.stroke();

    // Lower wake line
    ctx.beginPath();
    ctx.moveTo(boatX - 25, wakeY + wobble);
    ctx.quadraticCurveTo(
      boatX - len * 0.5, wakeY + spread + wobble,
      boatX - len, wakeY + spread * 1.5 + wobble
    );
    ctx.strokeStyle = `rgba(200, 180, 240, ${alpha})`;
    ctx.lineWidth = 1.2 - i * 0.3;
    ctx.stroke();
  }
}

function drawTitle(ctx) {
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";

  // "Odozi" with gradient matching app icon sail colors
  const titleGrad = ctx.createLinearGradient(460, 0, 740, 0);
  titleGrad.addColorStop(0, "#F5A623");
  titleGrad.addColorStop(0.4, "#E88A30");
  titleGrad.addColorStop(0.7, "#B060A0");
  titleGrad.addColorStop(1, "#2EC4B6");
  ctx.font = "bold 60px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif";
  ctx.fillStyle = titleGrad;
  ctx.fillText("Odozi", WIDTH / 2, HEIGHT * 0.18);

  // Tagline
  ctx.font = "26px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif";
  ctx.fillStyle = "rgba(237, 240, 250, 0.7)";
  ctx.fillText("Your daily journey inward.", WIDTH / 2, HEIGHT * 0.28);

  // Domain
  ctx.font = "15px -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif";
  ctx.fillStyle = "rgba(237, 240, 250, 0.3)";
  ctx.fillText("odozi.app", WIDTH / 2, HEIGHT * 0.93);
}

// Generate PNG frames, then use ffmpeg for high-quality GIF
const canvas = createCanvas(WIDTH, HEIGHT);
const ctx = canvas.getContext("2d");

const framesDir = path.join(__dirname, "..", "public", "frames");
if (!fs.existsSync(framesDir)) fs.mkdirSync(framesDir, { recursive: true });

for (let i = 0; i < FRAMES; i++) {
  drawFrame(ctx, i);
  const framePath = path.join(framesDir, `frame_${String(i).padStart(4, "0")}.png`);
  fs.writeFileSync(framePath, canvas.toBuffer("image/png"));
  process.stdout.write(`\rRendered frame ${i + 1}/${FRAMES}`);
}

console.log("\nFrames rendered. Now run ffmpeg to create high-quality GIF:");
console.log(`  cd ${path.join(__dirname, "..")} && \\`);
console.log(`  ffmpeg -y -framerate ${Math.round(1000 / DELAY)} -i public/frames/frame_%04d.png \\`);
console.log(`    -vf "palettegen=max_colors=256:stats_mode=diff" /tmp/palette.png && \\`);
console.log(`  ffmpeg -y -framerate ${Math.round(1000 / DELAY)} -i public/frames/frame_%04d.png \\`);
console.log(`    -i /tmp/palette.png -lavfi "paletteuse=dither=floyd_steinberg:diff_mode=rectangle" \\`);
console.log(`    public/og-image.gif`);
