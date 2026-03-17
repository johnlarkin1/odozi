const { createCanvas } = require("canvas");
const fs = require("fs");
const path = require("path");

const publicDir = path.join(__dirname, "..", "public");

// --- Colors from the app ---
const AMBER = "#F5A623";
const TEAL = "#2EC4B6";
const PURPLE = "#8C5CF5";
const PINK = "#E86BAD";
const DEEP = "#0D0D1F";
const WHITE = "#EDF0FA";

function hexToRgb(hex) {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return { r, g, b };
}
function rgba(hex, a) {
  const { r, g, b } = hexToRgb(hex);
  return `rgba(${r},${g},${b},${a})`;
}

// --- Sailboat drawing helpers (from app-icon-gallery.html) ---
function drawMainSail(ctx, mx, top, bot, width) {
  ctx.beginPath();
  ctx.moveTo(mx + 6, top);
  ctx.quadraticCurveTo(mx + width * 0.7, top + (bot - top) * 0.35, mx + width, bot - 10);
  ctx.lineTo(mx + 6, bot - 10);
  ctx.closePath();
}

function drawJibSail(ctx, mx, top, bot, width) {
  ctx.beginPath();
  ctx.moveTo(mx - 6, top + 20);
  ctx.quadraticCurveTo(mx - width * 0.65, top + (bot - top) * 0.45, mx - width, bot - 20);
  ctx.lineTo(mx - 6, bot - 20);
  ctx.closePath();
}

function drawHull(ctx, cx, y, w, h) {
  ctx.beginPath();
  ctx.moveTo(cx - w / 2, y);
  ctx.quadraticCurveTo(cx - w / 2.5, y + h, cx, y + h * 0.85);
  ctx.quadraticCurveTo(cx + w / 2.5, y + h * 0.7, cx + w / 2, y);
  ctx.closePath();
}

function compoundWave(x, baseY, params, S) {
  let y = baseY;
  for (const w of params) {
    y += Math.sin((x / S) * Math.PI * w.freq + w.phase) * w.amp;
  }
  return y;
}

function bowWaveOffset(x, hullCx, hullHalf, waveIdx) {
  const dx = x - hullCx;
  const dist = Math.abs(dx) / hullHalf;
  if (dist < 0.85) return 0;
  if (dist < 1.2) {
    const t = 1 - Math.abs(dist - 1.0) / 0.2;
    const rise = (12 - waveIdx * 1.5) * Math.max(0, t * t);
    return -rise;
  }
  if (dist < 1.8) {
    const t = (dist - 1.2) / 0.6;
    return Math.sin(t * Math.PI * 3) * (4 - waveIdx * 0.5) * (1 - t);
  }
  return 0;
}

function drawOceanBody(ctx, waterY, hullCx, hullW, palette, S) {
  const hullHalf = hullW / 2;

  const waveLayers = [
    { y: 0, params: [{ freq: 2.8, phase: 0.0, amp: 10 }, { freq: 5.2, phase: 1.2, amp: 5 }, { freq: 8.0, phase: 2.5, amp: 2.5 }] },
    { y: 18, params: [{ freq: 3.2, phase: 0.8, amp: 12 }, { freq: 6.0, phase: 2.0, amp: 4 }, { freq: 9.5, phase: 0.3, amp: 2 }] },
    { y: 34, params: [{ freq: 2.5, phase: 1.5, amp: 9 }, { freq: 5.8, phase: 3.1, amp: 5 }, { freq: 7.2, phase: 1.8, amp: 3 }] },
    { y: 50, params: [{ freq: 3.5, phase: 2.2, amp: 11 }, { freq: 6.5, phase: 0.5, amp: 4 }, { freq: 10, phase: 3.0, amp: 2 }] },
    { y: 66, params: [{ freq: 2.2, phase: 0.3, amp: 8 }, { freq: 5.0, phase: 2.8, amp: 5 }, { freq: 8.5, phase: 1.0, amp: 3 }] },
    { y: 82, params: [{ freq: 3.0, phase: 1.8, amp: 10 }, { freq: 7.0, phase: 0.8, amp: 3 }, { freq: 11, phase: 2.2, amp: 2 }] },
    { y: 98, params: [{ freq: 2.6, phase: 2.5, amp: 7 }, { freq: 4.5, phase: 1.5, amp: 4 }, { freq: 9.0, phase: 3.5, amp: 2 }] },
    { y: 114, params: [{ freq: 3.3, phase: 0.6, amp: 9 }, { freq: 6.2, phase: 2.5, amp: 3 }, { freq: 8.8, phase: 0.7, amp: 2 }] },
  ];

  function getWaveY(x, layerIdx) {
    const layer = waveLayers[layerIdx];
    let y = compoundWave(x, waterY + layer.y, layer.params, S);
    y += bowWaveOffset(x, hullCx, hullHalf, layerIdx);
    return y;
  }

  // Solid water body fill
  ctx.beginPath();
  ctx.moveTo(0, waterY - 5);
  for (let x = 0; x <= S; x += 3) {
    ctx.lineTo(x, getWaveY(x, 0));
  }
  ctx.lineTo(S, S);
  ctx.lineTo(0, S);
  ctx.closePath();
  const bodyGrad = ctx.createLinearGradient(0, waterY, 0, S);
  bodyGrad.addColorStop(0, palette.body);
  bodyGrad.addColorStop(0.4, palette.mid || palette.body);
  bodyGrad.addColorStop(1, palette.deep);
  ctx.fillStyle = bodyGrad;
  ctx.fill();

  // Hull reflection
  if (palette.reflectColor) {
    const refGrad = ctx.createLinearGradient(0, waterY, 0, waterY + S * 0.18);
    refGrad.addColorStop(0, rgba(palette.reflectColor, 0.1));
    refGrad.addColorStop(0.4, rgba(palette.reflectColor, 0.04));
    refGrad.addColorStop(1, "transparent");
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(hullCx - hullHalf * 0.7, waterY);
    ctx.lineTo(hullCx + hullHalf * 0.7, waterY);
    ctx.lineTo(hullCx + hullHalf * 0.3, waterY + S * 0.18);
    ctx.lineTo(hullCx - hullHalf * 0.3, waterY + S * 0.18);
    ctx.closePath();
    ctx.fillStyle = refGrad;
    ctx.fill();
    ctx.restore();
  }

  // Layered wave fills
  const crests = palette.crests || ["#2a5a80"];
  for (let i = 1; i < waveLayers.length; i++) {
    const color = crests[i % crests.length];
    const alpha = 0.14 - i * 0.01;
    ctx.beginPath();
    ctx.moveTo(0, getWaveY(0, i));
    for (let x = 3; x <= S; x += 3) {
      ctx.lineTo(x, getWaveY(x, i));
    }
    ctx.lineTo(S, S);
    ctx.lineTo(0, S);
    ctx.closePath();
    ctx.fillStyle = rgba(color, Math.max(0.03, alpha));
    ctx.fill();
  }

  // Crest highlight lines
  const foamColor = palette.foam || "#6abcd0";
  for (let i = 0; i < waveLayers.length; i++) {
    ctx.beginPath();
    for (let x = 0; x <= S; x += 2) {
      const y = getWaveY(x, i);
      if (x === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    const brightness = i < 3 ? 0.35 - i * 0.06 : 0.18 - (i - 3) * 0.02;
    ctx.strokeStyle = rgba(foamColor, Math.max(0.04, brightness));
    ctx.lineWidth = i < 2 ? 2.8 : i < 4 ? 2.0 : 1.2;
    ctx.stroke();

    if (i < 4) {
      ctx.beginPath();
      for (let x = 0; x <= S; x += 3) {
        const y = getWaveY(x, i) - 2;
        if (x === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
      }
      ctx.strokeStyle = rgba(palette.foamHighlight || "#ffffff", 0.08 - i * 0.015);
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  }

  // Waterline foam around hull
  ctx.beginPath();
  const foamBaseY = waterY + 3;
  const leftEdge = hullCx - hullHalf * 0.98;
  const rightEdge = hullCx + hullHalf * 0.98;
  for (let x = leftEdge; x <= rightEdge; x += 2) {
    const t = (x - leftEdge) / (rightEdge - leftEdge);
    const hullCurve = Math.sin(t * Math.PI) * 6;
    const micro = Math.sin(x * 0.12) * 1.5 + Math.sin(x * 0.28) * 0.8;
    const y = foamBaseY + hullCurve + micro;
    if (x <= leftEdge) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.strokeStyle = rgba(foamColor, 0.45);
  ctx.lineWidth = 2.5;
  ctx.stroke();

  ctx.beginPath();
  for (let x = leftEdge + 10; x <= rightEdge - 10; x += 2) {
    const t = (x - leftEdge) / (rightEdge - leftEdge);
    const hullCurve = Math.sin(t * Math.PI) * 4;
    const micro = Math.sin(x * 0.15 + 1) * 1.2;
    const y = foamBaseY - 1 + hullCurve + micro;
    if (x <= leftEdge + 10) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.strokeStyle = rgba("#ffffff", 0.12);
  ctx.lineWidth = 1.5;
  ctx.stroke();

  // Depth vignette
  const botF = ctx.createLinearGradient(0, S * 0.82, 0, S);
  botF.addColorStop(0, "transparent");
  botF.addColorStop(1, rgba(palette.deep, 0.7));
  ctx.fillStyle = botF;
  ctx.fillRect(0, S * 0.82, S, S * 0.18);
}

// ============================================================
// Cosmic Navigator (from app-icon-gallery.html drawCosmic)
// ============================================================
function drawCosmic(ctx, S) {
  // Deep background
  const bg = ctx.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S * 0.72);
  bg.addColorStop(0, "#1a1040");
  bg.addColorStop(0.6, "#0e0a22");
  bg.addColorStop(1, "#060410");
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, S, S);

  // Stars
  const rng = (seed) => {
    let s = seed;
    return () => {
      s = (s * 16807 + 0) % 2147483647;
      return s / 2147483647;
    };
  };
  const rand = rng(42);
  for (let i = 0; i < 200; i++) {
    const x = rand() * S;
    const y = rand() * S;
    const isBright = rand() > 0.85;
    const r = isBright ? rand() * 3.5 + 2.0 : rand() * 2.2 + 0.3;
    const a = isBright ? rand() * 0.3 + 0.7 : rand() * 0.6 + 0.2;
    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = rgba(WHITE, a);
    ctx.fill();
    if (isBright) {
      const glow = ctx.createRadialGradient(x, y, r * 0.5, x, y, r * 4);
      glow.addColorStop(0, rgba(WHITE, 0.15));
      glow.addColorStop(1, "transparent");
      ctx.fillStyle = glow;
      ctx.beginPath();
      ctx.arc(x, y, r * 4, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // Nebula glow - pink + purple
  const neb1 = ctx.createRadialGradient(S * 0.4, S * 0.38, 0, S * 0.4, S * 0.38, S * 0.35);
  neb1.addColorStop(0, "rgba(232,107,173,0.18)");
  neb1.addColorStop(0.5, "rgba(140,92,245,0.12)");
  neb1.addColorStop(1, "transparent");
  ctx.fillStyle = neb1;
  ctx.fillRect(0, 0, S, S);

  const neb2 = ctx.createRadialGradient(S * 0.6, S * 0.45, 0, S * 0.6, S * 0.45, S * 0.3);
  neb2.addColorStop(0, "rgba(140,92,245,0.22)");
  neb2.addColorStop(0.6, "rgba(90,40,200,0.08)");
  neb2.addColorStop(1, "transparent");
  ctx.fillStyle = neb2;
  ctx.fillRect(0, 0, S, S);

  // Boat glow
  const boatGlow = ctx.createRadialGradient(S / 2, S * 0.49, 0, S / 2, S * 0.49, S * 0.28);
  boatGlow.addColorStop(0, "rgba(245,166,35,0.12)");
  boatGlow.addColorStop(1, "transparent");
  ctx.fillStyle = boatGlow;
  ctx.fillRect(0, 0, S, S);

  // Sails with cosmic gradient
  const mx = S * 0.47;
  const sailTop = S * 0.13;
  const sailBot = S * 0.65;

  const sailGrad = ctx.createLinearGradient(mx, sailTop, mx + 315, sailBot);
  sailGrad.addColorStop(0, "#FFD76E");
  sailGrad.addColorStop(0.4, AMBER);
  sailGrad.addColorStop(0.8, "#E86B5A");
  sailGrad.addColorStop(1, PINK);
  drawMainSail(ctx, mx, sailTop, sailBot, 315);
  ctx.fillStyle = sailGrad;
  ctx.fill();

  const jibGrad = ctx.createLinearGradient(mx, sailTop, mx - 235, sailBot);
  jibGrad.addColorStop(0, "#FFD76E");
  jibGrad.addColorStop(0.5, "#E8A040");
  jibGrad.addColorStop(1, "#D06080");
  drawJibSail(ctx, mx, sailTop, sailBot, 235);
  ctx.fillStyle = jibGrad;
  ctx.fill();

  // Mast
  ctx.strokeStyle = "#E8B860";
  ctx.lineWidth = 6;
  ctx.beginPath();
  ctx.moveTo(mx, sailTop - 10);
  ctx.lineTo(mx, sailBot + 12);
  ctx.stroke();

  // Hull
  drawHull(ctx, S * 0.49, sailBot + 2, S * 0.58, 80);
  const hGrad = ctx.createLinearGradient(S * 0.2, sailBot, S * 0.78, sailBot + 80);
  hGrad.addColorStop(0, "#C07830");
  hGrad.addColorStop(1, "#8C5CF5");
  ctx.fillStyle = hGrad;
  ctx.fill();

  // Ocean
  drawOceanBody(ctx, S * 0.68, S * 0.49, S * 0.58, {
    body: "#121a40",
    mid: "#0e1435",
    deep: "#060818",
    crests: ["#2840a0", "#1a3080", PURPLE, "#3050b0", TEAL, "#2a4590", "#1a3570", "#3a5aaa"],
    foam: "#5a80e0",
    foamHighlight: "#a0c0ff",
    reflectColor: AMBER,
  }, S);
}

// Generate at 1024x1024 (full resolution) then export at multiple sizes
const fullSize = 1024;
const fullCanvas = createCanvas(fullSize, fullSize);
const fullCtx = fullCanvas.getContext("2d");
drawCosmic(fullCtx, fullSize);

// Save 1024 version
const fullBuf = fullCanvas.toBuffer("image/png");
fs.writeFileSync(path.join(publicDir, "app-icon-cosmic.png"), fullBuf);
console.log(`Generated app-icon-cosmic.png (${fullBuf.length} bytes)`);

// Downscale to favicon sizes
const sizes = [
  { size: 16, name: "favicon-16x16.png" },
  { size: 32, name: "favicon-32x32.png" },
  { size: 48, name: "favicon-48x48.png" },
  { size: 180, name: "apple-touch-icon.png" },
];

for (const { size, name } of sizes) {
  const canvas = createCanvas(size, size);
  const ctx = canvas.getContext("2d");
  // Draw the full-res icon scaled down
  ctx.drawImage(fullCanvas, 0, 0, size, size);
  const buf = canvas.toBuffer("image/png");
  fs.writeFileSync(path.join(publicDir, name), buf);
  console.log(`Generated ${name} (${buf.length} bytes)`);
}

console.log("Done!");
