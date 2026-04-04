"use client";

import { useEffect, useRef } from "react";
import { getWaveHeight } from "@/components/InteractiveOcean/waveEngine";
import { WAVE_LAYERS, COLORS } from "@/components/InteractiveOcean/types";

const W = 1200;
const H = 630;

// Brand colors (matching globals.css)
const ACCENT_AMBER = "#F5A623";
const ACCENT_TEAL = "#2EC4B6";
const COSMIC_PURPLE = "#8C5CF5";
const NEBULA_PINK = "#E86BAD";
const DEEP_SPACE = "#0D0D1F";

// Particle colors for floating orbs
const PARTICLE_COLORS = [
  ACCENT_AMBER,
  ACCENT_TEAL,
  COSMIC_PURPLE,
  NEBULA_PINK,
  "#F5C96A",
  "#5BE0D0",
];

// Boat travel: sails slowly left-to-right across the full canvas over ~12 seconds
const BOAT_CYCLE_DURATION = 6;

interface Star {
  x: number;
  y: number;
  size: number;
  phase: number;
  brightness: number;
}

interface FloatingParticle {
  x: number;
  y: number;
  radius: number;
  color: string;
  speed: number;
  phase: number;
  opacity: number;
}

function seededRandom(seed: number): number {
  const x = Math.sin(seed * 127.1 + seed * 311.7) * 43758.5453;
  return x - Math.floor(x);
}

function createStars(): Star[] {
  const stars: Star[] = [];
  for (let i = 0; i < 80; i++) {
    stars.push({
      x: seededRandom(i * 7 + 1) * W,
      y: seededRandom(i * 13 + 3) * H * 0.52,
      size: 0.4 + seededRandom(i * 29 + 7) * 1.6,
      phase: seededRandom(i * 41 + 11) * Math.PI * 2,
      brightness: 0.25 + seededRandom(i * 53 + 17) * 0.75,
    });
  }
  return stars;
}

function createParticles(): FloatingParticle[] {
  const particles: FloatingParticle[] = [];
  for (let i = 0; i < 12; i++) {
    particles.push({
      x: seededRandom(i * 31 + 5) * W,
      y: seededRandom(i * 47 + 9) * H,
      radius: 1.5 + seededRandom(i * 61 + 13) * 3,
      color: PARTICLE_COLORS[i % PARTICLE_COLORS.length],
      speed: 6 + seededRandom(i * 71 + 19) * 12,
      phase: seededRandom(i * 83 + 23) * Math.PI * 2,
      opacity: 0.12 + seededRandom(i * 97 + 29) * 0.2,
    });
  }
  return particles;
}

// Smooth ease-in-out for the boat travel
function smoothStep(t: number): number {
  return t * t * (3 - 2 * t);
}

function drawBackground(ctx: CanvasRenderingContext2D) {
  const grad = ctx.createLinearGradient(0, 0, 0, H);
  grad.addColorStop(0, DEEP_SPACE);
  grad.addColorStop(0.35, "#10102a");
  grad.addColorStop(0.55, "#161440");
  grad.addColorStop(1, "#121035");
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);
}

function drawGradientOrbs(ctx: CanvasRenderingContext2D, time: number) {
  const orbs = [
    { x: W * 0.25, y: H * 0.2, r: 280, color: COSMIC_PURPLE, baseAlpha: 0.07 },
    { x: W * 0.72, y: H * 0.18, r: 220, color: NEBULA_PINK, baseAlpha: 0.05 },
    { x: W * 0.5, y: H * 0.5, r: 350, color: ACCENT_TEAL, baseAlpha: 0.035 },
    { x: W * 0.12, y: H * 0.65, r: 200, color: COSMIC_PURPLE, baseAlpha: 0.03 },
    { x: W * 0.88, y: H * 0.6, r: 180, color: ACCENT_AMBER, baseAlpha: 0.03 },
  ];

  for (const orb of orbs) {
    const pulse = 1 + Math.sin(time * 0.4 + orb.x * 0.008) * 0.12;
    const alpha = orb.baseAlpha * pulse;
    const grad = ctx.createRadialGradient(orb.x, orb.y, 0, orb.x, orb.y, orb.r);
    const hex = Math.round(alpha * 255)
      .toString(16)
      .padStart(2, "0");
    grad.addColorStop(0, orb.color + hex);
    grad.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(orb.x, orb.y, orb.r, 0, Math.PI * 2);
    ctx.fill();
  }
}

function drawStars(ctx: CanvasRenderingContext2D, stars: Star[], time: number) {
  for (const star of stars) {
    const twinkle =
      star.brightness *
      (0.35 + 0.65 * (0.5 + 0.5 * Math.sin(time * 1.2 + star.phase)));

    ctx.beginPath();
    ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(237, 240, 250, ${twinkle})`;
    ctx.fill();

    // Cross-glow on brighter stars
    if (star.size > 1.0 && twinkle > 0.45) {
      ctx.save();
      ctx.globalAlpha = twinkle * 0.25;
      ctx.strokeStyle = COLORS.starWhite;
      ctx.lineWidth = 0.4;
      const len = star.size * 2.5;
      ctx.beginPath();
      ctx.moveTo(star.x - len, star.y);
      ctx.lineTo(star.x + len, star.y);
      ctx.moveTo(star.x, star.y - len);
      ctx.lineTo(star.x, star.y + len);
      ctx.stroke();
      ctx.restore();
    }
  }
}

function drawOcean(ctx: CanvasRenderingContext2D, time: number) {
  const baselineY = H * 0.62;

  // Deep ocean fill
  const waterGrad = ctx.createLinearGradient(0, baselineY - 20, 0, H);
  waterGrad.addColorStop(0, "#181656");
  waterGrad.addColorStop(0.25, "#1c1a5e");
  waterGrad.addColorStop(0.5, "#1a1852");
  waterGrad.addColorStop(1, "#120e3a");
  ctx.fillStyle = waterGrad;
  ctx.fillRect(0, baselineY - 20, W, H - baselineY + 20);

  // Wave bands using shared wave engine
  const bands = [
    { offset: -14, color: "#1c1858", alpha: 0.55, phaseOffset: 0 },
    { offset: -6, color: "#201c5e", alpha: 0.5, phaseOffset: 1.0 },
    { offset: 4, color: "#242066", alpha: 0.45, phaseOffset: 2.2 },
    { offset: 14, color: "#28246e", alpha: 0.38, phaseOffset: 3.5 },
    { offset: 24, color: "#2c2876", alpha: 0.32, phaseOffset: 4.8 },
    { offset: 36, color: "#302c7e", alpha: 0.25, phaseOffset: 6.0 },
  ];

  for (const band of bands) {
    ctx.save();
    ctx.globalAlpha = band.alpha;
    ctx.fillStyle = band.color;
    ctx.beginPath();
    ctx.moveTo(0, H);
    for (let x = 0; x <= W; x += 2) {
      const waveY =
        baselineY +
        band.offset +
        getWaveHeight(x, time, W, WAVE_LAYERS, band.phaseOffset);
      ctx.lineTo(x, waveY);
    }
    ctx.lineTo(W, H);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  // Foam line on front wave
  ctx.save();
  ctx.strokeStyle = "white";
  ctx.lineWidth = 1.0;
  ctx.lineCap = "round";
  for (let x = 0; x < W; x += 2) {
    const foamNoise =
      Math.sin(x * 0.02 + time * 1.2) * 0.5 +
      Math.sin(x * 0.05 + time * 0.8) * 0.3 +
      0.2;
    if (foamNoise < 0.35) continue;
    const wy = baselineY + getWaveHeight(x, time, W, WAVE_LAYERS, 0);
    const wy2 = baselineY + getWaveHeight(x + 2, time, W, WAVE_LAYERS, 0);
    ctx.globalAlpha = Math.min(foamNoise * 0.35, 0.2);
    ctx.beginPath();
    ctx.moveTo(x, wy);
    ctx.lineTo(x + 2, wy2);
    ctx.stroke();
  }
  ctx.restore();

  // Subtle horizon glow
  const hGrad = ctx.createLinearGradient(0, baselineY - 18, 0, baselineY + 8);
  hGrad.addColorStop(0, "rgba(140, 92, 245, 0)");
  hGrad.addColorStop(0.5, "rgba(140, 92, 245, 0.06)");
  hGrad.addColorStop(1, "rgba(140, 92, 245, 0)");
  ctx.fillStyle = hGrad;
  ctx.fillRect(0, baselineY - 18, W, 26);
}

function drawBoat(ctx: CanvasRenderingContext2D, time: number) {
  const baselineY = H * 0.62;

  // Boat travels left-to-right over BOAT_CYCLE_DURATION seconds, then loops
  const cycleT = (time % BOAT_CYCLE_DURATION) / BOAT_CYCLE_DURATION;
  const eased = smoothStep(cycleT);
  // Start off-screen left, end off-screen right
  const boatX = -80 + eased * (W + 160);

  const waveY = getWaveHeight(boatX, time, W, WAVE_LAYERS, 0);
  const boatY = baselineY + waveY - 8;

  // Tilt from wave slope
  const dx = 2;
  const h1 = getWaveHeight(boatX - dx, time, W, WAVE_LAYERS, 0);
  const h2 = getWaveHeight(boatX + dx, time, W, WAVE_LAYERS, 0);
  const tilt = Math.atan((h2 - h1) / (2 * dx)) * 0.5;

  const scale = 1.8;
  const hw = 25 * scale;
  const hullDepth = 13 * scale;
  const mastHeight = 42 * scale;
  const sailBillow = Math.sin(time * 1.3) * 2.5 * scale + 22 * scale;

  // --- Reflection (draw first, under the boat) ---
  ctx.save();
  ctx.translate(boatX, boatY + hullDepth * 0.5 + 8);
  ctx.scale(1, -0.2);
  ctx.rotate(-tilt * 0.3);
  ctx.globalAlpha = 0.08;

  // Reflected sail silhouette
  ctx.beginPath();
  ctx.moveTo(2, -mastHeight + 4);
  ctx.lineTo(2, -8 * scale);
  ctx.quadraticCurveTo(sailBillow * 0.5, -mastHeight * 0.45, sailBillow * 0.7, -mastHeight * 0.4);
  ctx.quadraticCurveTo(sailBillow * 0.4, -mastHeight * 0.6, 2, -mastHeight + 4);
  ctx.closePath();
  const reflGrad = ctx.createLinearGradient(0, -mastHeight, sailBillow, 0);
  reflGrad.addColorStop(0, ACCENT_TEAL);
  reflGrad.addColorStop(1, COSMIC_PURPLE);
  ctx.fillStyle = reflGrad;
  ctx.fill();
  ctx.restore();

  // --- Wake trail behind the boat ---
  drawWake(ctx, boatX, boatY + hullDepth * 0.3, time, eased);

  // --- The boat itself ---
  ctx.save();
  ctx.translate(boatX, boatY);
  ctx.rotate(tilt);

  // Water line glow
  ctx.globalAlpha = 0.1;
  ctx.fillStyle = ACCENT_TEAL;
  ctx.beginPath();
  ctx.ellipse(0, hullDepth + 3, hw + 8, 5, 0, 0, Math.PI * 2);
  ctx.fill();

  // Hull body
  ctx.beginPath();
  ctx.moveTo(-hw, -1);
  ctx.lineTo(-hw + 4 * scale, 0);
  ctx.quadraticCurveTo(-hw + 6 * scale, hullDepth, 0, hullDepth + 4);
  ctx.quadraticCurveTo(hw - 6 * scale, hullDepth, hw - 4 * scale, 0);
  ctx.lineTo(hw, -1);
  ctx.closePath();
  const hullGrad = ctx.createLinearGradient(0, -3, 0, hullDepth + 4);
  hullGrad.addColorStop(0, "#f0e6d3");
  hullGrad.addColorStop(0.4, "#c4a67a");
  hullGrad.addColorStop(1, "#7a5c3a");
  ctx.fillStyle = hullGrad;
  ctx.globalAlpha = 0.92;
  ctx.fill();

  // Hull rim highlight
  ctx.beginPath();
  ctx.moveTo(-hw + 6 * scale, 0);
  ctx.lineTo(hw - 6 * scale, 0);
  ctx.strokeStyle = "white";
  ctx.globalAlpha = 0.3;
  ctx.lineWidth = 1.5;
  ctx.stroke();

  // Hull accent stripe
  ctx.beginPath();
  ctx.moveTo(-hw + 12 * scale, hullDepth * 0.7);
  ctx.quadraticCurveTo(0, hullDepth + 2, hw - 12 * scale, hullDepth * 0.7);
  ctx.strokeStyle = COSMIC_PURPLE;
  ctx.globalAlpha = 0.25;
  ctx.lineWidth = 2;
  ctx.stroke();

  // Mast
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(0, -mastHeight);
  ctx.strokeStyle = "#d4c5a9";
  ctx.globalAlpha = 0.85;
  ctx.lineWidth = 2.5;
  ctx.stroke();

  // --- Main sail (right side, billowing with wind) ---
  ctx.beginPath();
  ctx.moveTo(2, -mastHeight + 4);
  ctx.lineTo(2, -8 * scale);
  // Two control points for a fuller, more natural billowing shape
  ctx.bezierCurveTo(
    sailBillow * 0.4, -6 * scale,
    sailBillow * 0.8, -mastHeight * 0.35,
    sailBillow, -mastHeight * 0.38,
  );
  ctx.bezierCurveTo(
    sailBillow * 0.7, -mastHeight * 0.55,
    sailBillow * 0.3, -mastHeight * 0.8,
    2, -mastHeight + 4,
  );
  ctx.closePath();

  const sailGrad = ctx.createLinearGradient(0, -mastHeight, sailBillow, -8 * scale);
  sailGrad.addColorStop(0, ACCENT_TEAL);
  sailGrad.addColorStop(0.6, COSMIC_PURPLE);
  sailGrad.addColorStop(1, NEBULA_PINK);
  ctx.fillStyle = sailGrad;
  ctx.globalAlpha = 0.6;
  ctx.fill();

  // Sail highlight edge
  ctx.strokeStyle = "rgba(255,255,255,0.12)";
  ctx.lineWidth = 1;
  ctx.stroke();

  // Sail seam lines
  ctx.strokeStyle = "white";
  ctx.lineWidth = 0.5;
  for (let i = 1; i <= 4; i++) {
    const t = i / 5;
    const sy = -mastHeight + 4 + t * (mastHeight - 12 * scale);
    const ex = sailBillow * (0.2 + t * 0.5);
    const ey = -mastHeight * (0.7 - t * 0.3);
    ctx.globalAlpha = 0.06 + t * 0.02;
    ctx.beginPath();
    ctx.moveTo(2, sy);
    ctx.lineTo(ex, ey);
    ctx.stroke();
  }

  // --- Jib sail (smaller front sail) ---
  const jibWidth = sailBillow * 0.45;
  ctx.beginPath();
  ctx.moveTo(-1, -mastHeight + 6);
  ctx.lineTo(-1, -10 * scale);
  ctx.bezierCurveTo(
    -jibWidth * 0.3, -8 * scale,
    -jibWidth * 0.6, -mastHeight * 0.4,
    -jibWidth, -mastHeight * 0.42,
  );
  ctx.bezierCurveTo(
    -jibWidth * 0.5, -mastHeight * 0.6,
    -jibWidth * 0.2, -mastHeight * 0.8,
    -1, -mastHeight + 6,
  );
  ctx.closePath();
  const jibGrad = ctx.createLinearGradient(-jibWidth, -mastHeight, 0, -10 * scale);
  jibGrad.addColorStop(0, ACCENT_AMBER);
  jibGrad.addColorStop(0.5, "#E88A30");
  jibGrad.addColorStop(1, COSMIC_PURPLE);
  ctx.fillStyle = jibGrad;
  ctx.globalAlpha = 0.45;
  ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,0.08)";
  ctx.lineWidth = 0.8;
  ctx.stroke();

  // Flag at masthead
  const flagWave = Math.sin(time * 4.5) * 4;
  const flagWave2 = Math.sin(time * 6 + 1) * 2;
  ctx.beginPath();
  ctx.moveTo(0, -mastHeight);
  ctx.quadraticCurveTo(
    7 + flagWave,
    -mastHeight - 2 + flagWave2,
    14 + flagWave,
    -mastHeight + 2,
  );
  ctx.lineTo(0, -mastHeight + 7);
  ctx.closePath();
  ctx.fillStyle = ACCENT_AMBER;
  ctx.globalAlpha = 0.8;
  ctx.fill();

  ctx.restore();
}

function drawWake(
  ctx: CanvasRenderingContext2D,
  boatX: number,
  wakeY: number,
  time: number,
  eased: number,
) {
  // Only draw wake when boat is on-screen
  if (boatX < -40 || boatX > W + 40) return;

  const wakeLen = Math.min(boatX + 80, 280) * Math.min(eased * 4, 1);
  if (wakeLen <= 5) return;

  ctx.save();
  for (let i = 0; i < 4; i++) {
    const spread = (i + 1) * 3.5;
    const len = wakeLen * (1 - i * 0.2);
    const alpha = 0.07 - i * 0.015;
    const wobble = Math.sin(time * Math.PI * 5 + i * 1.2) * 1.5;

    // Upper wake line
    ctx.beginPath();
    ctx.moveTo(boatX - 20, wakeY + wobble);
    ctx.quadraticCurveTo(
      boatX - len * 0.5,
      wakeY - spread + wobble,
      boatX - len,
      wakeY - spread * 1.8 + wobble,
    );
    ctx.strokeStyle = `rgba(200, 190, 255, ${alpha})`;
    ctx.lineWidth = 1.2 - i * 0.2;
    ctx.stroke();

    // Lower wake line
    ctx.beginPath();
    ctx.moveTo(boatX - 20, wakeY + wobble);
    ctx.quadraticCurveTo(
      boatX - len * 0.5,
      wakeY + spread + wobble,
      boatX - len,
      wakeY + spread * 1.8 + wobble,
    );
    ctx.strokeStyle = `rgba(200, 190, 255, ${alpha})`;
    ctx.lineWidth = 1.2 - i * 0.2;
    ctx.stroke();
  }

  // Sparkle dots along wake
  ctx.fillStyle = "white";
  for (let i = 0; i < 8; i++) {
    const t = i / 8;
    const wx = boatX - 30 - t * wakeLen * 0.7;
    const wy = wakeY + Math.sin(time * 3 + i * 2) * (t * 8 + 1);
    const sparkleAlpha = (1 - t) * 0.12 * (0.5 + 0.5 * Math.sin(time * 4 + i));
    if (sparkleAlpha < 0.02) continue;
    ctx.globalAlpha = sparkleAlpha;
    ctx.beginPath();
    ctx.arc(wx, wy, 1.2, 0, Math.PI * 2);
    ctx.fill();
  }

  ctx.restore();
}

function drawFloatingParticles(
  ctx: CanvasRenderingContext2D,
  particles: FloatingParticle[],
  time: number,
) {
  for (const p of particles) {
    const y = (((p.y - time * p.speed) % (H + 40)) + H + 40) % (H + 40) - 20;
    const x = p.x + Math.sin(time * 0.6 + p.phase) * 18;

    const edgeFade = Math.min(1, y / 80, (H - y) / 80);
    const alpha = p.opacity * Math.max(0, edgeFade);
    if (alpha <= 0) continue;

    // Soft glow
    const grad = ctx.createRadialGradient(x, y, 0, x, y, p.radius * 3.5);
    const hex = Math.round(alpha * 255)
      .toString(16)
      .padStart(2, "0");
    grad.addColorStop(0, p.color + hex);
    grad.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(x, y, p.radius * 3.5, 0, Math.PI * 2);
    ctx.fill();

    // Core
    ctx.beginPath();
    ctx.arc(x, y, p.radius, 0, Math.PI * 2);
    ctx.fillStyle = p.color;
    ctx.globalAlpha = alpha * 0.7;
    ctx.fill();
    ctx.globalAlpha = 1;
  }
}

// Title text is rendered as HTML overlay (see UnfurlCanvas component JSX)
// to get perfect CSS text rendering with bg-clip-text gradient.

function drawVignette(ctx: CanvasRenderingContext2D) {
  const grad = ctx.createRadialGradient(
    W / 2,
    H / 2,
    W * 0.2,
    W / 2,
    H / 2,
    W * 0.72,
  );
  grad.addColorStop(0, "rgba(0,0,0,0)");
  grad.addColorStop(1, "rgba(0,0,0,0.3)");
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);
}

export function UnfurlCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animationRef = useRef<number>(0);
  const starsRef = useRef<Star[]>([]);
  const particlesRef = useRef<FloatingParticle[]>([]);
  const startTimeRef = useRef<number>(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    // Scale canvas buffer for Retina/HiDPI — keeps text and shapes crisp
    const dpr = window.devicePixelRatio || 1;
    canvas.width = W * dpr;
    canvas.height = H * dpr;
    ctx.scale(dpr, dpr);

    starsRef.current = createStars();
    particlesRef.current = createParticles();
    startTimeRef.current = performance.now() / 1000;
    animate();

    function animate() {
      if (!ctx) return;
      const time = performance.now() / 1000 - startTimeRef.current;

      drawBackground(ctx);
      drawGradientOrbs(ctx, time);
      drawStars(ctx, starsRef.current, time);
      drawFloatingParticles(ctx, particlesRef.current, time);
      drawOcean(ctx, time);
      drawBoat(ctx, time);
      drawVignette(ctx);

      animationRef.current = requestAnimationFrame(animate);
    }

    return () => cancelAnimationFrame(animationRef.current);
  }, []);

  return (
    <div style={{ position: "relative", width: `${W}px`, height: `${H}px` }}>
      <canvas
        ref={canvasRef}
        style={{ width: `${W}px`, height: `${H}px`, imageRendering: "auto" }}
      />
      {/* Text overlay — uses CSS rendering for perfect glyphs + bg-clip-text gradient */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          pointerEvents: "none",
        }}
      >
        <h1
          className="font-heading"
          style={{
            marginTop: `${H * 0.09}px`,
            fontSize: "104px",
            fontWeight: 700,
            lineHeight: 1.1,
            background: `linear-gradient(to right, ${ACCENT_AMBER}, ${COSMIC_PURPLE}, ${ACCENT_TEAL})`,
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
            backgroundClip: "text",
          }}
        >
          Odyssey
        </h1>
        <p
          style={{
            marginTop: "4px",
            fontSize: "36px",
            fontWeight: 300,
            color: "rgba(237, 240, 250, 0.7)",
          }}
        >
          a journal for your journey
        </p>
        <p
          style={{
            position: "absolute",
            bottom: `${H * 0.03}px`,
            fontSize: "15px",
            fontWeight: 400,
            color: "rgba(237, 240, 250, 0.28)",
          }}
        >
          odozi.app
        </p>
      </div>
    </div>
  );
}
