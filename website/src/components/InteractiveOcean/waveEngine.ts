import {
  type WaveLayer,
  type BoatState,
  type MouseState,
  WAVE_LAYERS,
  SUBTLE_WAVE_LAYERS,
  COLORS,
  BOAT_WIDTH,
  BOAT_ACCEL_LERP,
  TILT_LERP,
  MAX_TILT,
  MAX_WAKE_PARTICLES,
  DRIFT_SPEED,
  MOUSE_RIPPLE_RADIUS,
  MOUSE_RIPPLE_STRENGTH,
} from "./types";

// ── Wave math ──────────────────────────────────────────────

export function getWaveHeight(
  x: number,
  time: number,
  canvasWidth: number,
  layers: WaveLayer[] = WAVE_LAYERS,
  phaseOffset: number = 0,
): number {
  const scale = 1440 / canvasWidth;
  let y = 0;
  for (const layer of layers) {
    y +=
      layer.amplitude *
      Math.sin(
        x * layer.frequency * scale +
          time * layer.speed +
          layer.phase +
          phaseOffset,
      );
  }
  return y;
}

/** Get wave height including mouse ripple displacement */
export function getWaveHeightWithMouse(
  x: number,
  time: number,
  canvasWidth: number,
  mouse: MouseState | null,
  layers: WaveLayer[] = WAVE_LAYERS,
  phaseOffset: number = 0,
): number {
  let y = getWaveHeight(x, time, canvasWidth, layers, phaseOffset);

  if (mouse?.active) {
    const dx = x - mouse.x;
    const dist = Math.abs(dx);
    if (dist < MOUSE_RIPPLE_RADIUS) {
      // Smooth radial falloff with quintic smootherstep (zero 1st & 2nd derivatives at boundary)
      const falloff = 1 - dist / MOUSE_RIPPLE_RADIUS;
      const smoothFalloff = falloff * falloff * falloff * (falloff * (falloff * 6 - 15) + 10);

      // Primary wave — broad slow-moving swell
      const primaryWave =
        Math.sin(dist * 0.025 - time * 2.5) * MOUSE_RIPPLE_STRENGTH * smoothFalloff;

      // Secondary ripple — gentler, wider waves on top
      const secondaryRipple =
        Math.sin(dist * 0.06 - time * 4.5) * MOUSE_RIPPLE_STRENGTH * 0.25 * smoothFalloff;

      // Tertiary fine ripple
      const fineRipple =
        Math.sin(dist * 0.12 - time * 6) * MOUSE_RIPPLE_STRENGTH * 0.10 * (smoothFalloff * smoothFalloff);

      y += primaryWave + secondaryRipple + fineRipple;
    }
  }

  return y;
}

export function getWaveSlope(
  x: number,
  time: number,
  canvasWidth: number,
  mouse: MouseState | null,
  layers: WaveLayer[] = WAVE_LAYERS,
  phaseOffset: number = 0,
): number {
  // Numerical derivative for accuracy including mouse ripple
  const dx = 1;
  const h1 = getWaveHeightWithMouse(x - dx, time, canvasWidth, mouse, layers, phaseOffset);
  const h2 = getWaveHeightWithMouse(x + dx, time, canvasWidth, mouse, layers, phaseOffset);
  return (h2 - h1) / (2 * dx);
}

// ── Rendering ──────────────────────────────────────────────

function drawWaveBand(
  ctx: CanvasRenderingContext2D,
  time: number,
  width: number,
  height: number,
  baselineY: number,
  verticalOffset: number,
  color: string,
  opacity: number,
  phaseOffset: number,
  mouse: MouseState | null,
  layers: WaveLayer[] = WAVE_LAYERS,
) {
  ctx.save();
  ctx.globalAlpha = opacity;
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(0, height);

  for (let x = 0; x <= width; x += 2) {
    const waveY =
      baselineY +
      verticalOffset +
      getWaveHeightWithMouse(x, time, width, mouse, layers, phaseOffset);
    ctx.lineTo(x, waveY);
  }

  ctx.lineTo(width, height);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function drawFoam(
  ctx: CanvasRenderingContext2D,
  time: number,
  width: number,
  baselineY: number,
  phaseOffset: number,
  mouse: MouseState | null,
  layers: WaveLayer[] = WAVE_LAYERS,
) {
  ctx.save();

  // Foam line
  ctx.strokeStyle = "white";
  ctx.lineWidth = 1.5;
  ctx.lineCap = "round";

  for (let x = 0; x < width; x += 3) {
    const foamNoise =
      Math.sin(x * 0.02 + time * 1.2) * 0.5 +
      Math.sin(x * 0.05 + time * 0.8) * 0.3 +
      0.2;
    if (foamNoise < 0.3) continue;

    const waveY =
      baselineY + getWaveHeightWithMouse(x, time, width, mouse, layers, phaseOffset);
    const nextWaveY =
      baselineY + getWaveHeightWithMouse(x + 3, time, width, mouse, layers, phaseOffset);

    ctx.globalAlpha = Math.min(foamNoise * 0.5, 0.35);
    ctx.beginPath();
    ctx.moveTo(x, waveY);
    ctx.lineTo(x + 3, nextWaveY);
    ctx.stroke();
  }

  // Foam bubbles
  ctx.fillStyle = "white";
  for (let x = 10; x < width; x += 60 + Math.sin(x * 0.1) * 20) {
    const waveY =
      baselineY + getWaveHeightWithMouse(x, time, width, mouse, layers, phaseOffset);
    const bubbleNoise = Math.sin(x * 0.03 + time * 1.5);
    if (bubbleNoise < 0.2) continue;

    const radius = 1.2 + bubbleNoise * 1.2;
    ctx.globalAlpha = 0.08 + bubbleNoise * 0.1;
    ctx.beginPath();
    ctx.arc(x, waveY + 2, radius, 0, Math.PI * 2);
    ctx.fill();

    if (bubbleNoise > 0.5) {
      ctx.globalAlpha = 0.06;
      ctx.beginPath();
      ctx.arc(x + 8, waveY + 5, radius * 0.7, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  ctx.restore();
}

/** Draw mouse ripple glow effect */
function drawMouseRipple(
  ctx: CanvasRenderingContext2D,
  mouse: MouseState | null,
  time: number,
  intensity: number = 1.0,
) {
  if (!mouse?.active) return;

  ctx.save();
  // Subtle radial glow at mouse position
  const glowAlpha1 = (0.14 * intensity).toFixed(3);
  const glowAlpha2 = (0.08 * intensity).toFixed(3);
  const gradient = ctx.createRadialGradient(
    mouse.x, mouse.y, 0,
    mouse.x, mouse.y, MOUSE_RIPPLE_RADIUS * 0.6,
  );
  gradient.addColorStop(0, `rgba(46, 196, 182, ${glowAlpha1})`);
  gradient.addColorStop(0.4, `rgba(140, 92, 245, ${glowAlpha2})`);
  gradient.addColorStop(1, "rgba(0, 0, 0, 0)");
  ctx.fillStyle = gradient;
  ctx.fillRect(
    mouse.x - MOUSE_RIPPLE_RADIUS,
    mouse.y - MOUSE_RIPPLE_RADIUS,
    MOUSE_RIPPLE_RADIUS * 2,
    MOUSE_RIPPLE_RADIUS * 2,
  );

  // Concentric ripple rings — propagating outward
  ctx.strokeStyle = "rgba(255, 255, 255, 0.1)";
  ctx.lineWidth = 1.2;
  for (let i = 0; i < 3; i++) {
    const ringRadius = ((time * 50 + i * 50) % 160) + 8;
    const alpha = 0.06 * intensity * (1 - ringRadius / 168);
    if (alpha <= 0) continue;
    ctx.globalAlpha = alpha;
    ctx.beginPath();
    ctx.arc(mouse.x, mouse.y, ringRadius, 0, Math.PI * 2);
    ctx.stroke();
  }

  ctx.restore();
}

export function renderOcean(
  ctx: CanvasRenderingContext2D,
  time: number,
  width: number,
  height: number,
  phaseOffset: number,
  mouse: MouseState | null,
  subtle: boolean = false,
) {
  ctx.clearRect(0, 0, width, height);

  if (subtle) {
    // Subtle mode: different wave shape, slower, softer — pure rolling swells
    const baselineY = height * 0.5;

    drawWaveBand(ctx, time, width, height, baselineY, -5, COLORS.cosmicPurple, 0.05, phaseOffset, mouse, SUBTLE_WAVE_LAYERS);
    drawWaveBand(ctx, time, width, height, baselineY, -2, COLORS.accentTeal, 0.06, phaseOffset + 0.8, mouse, SUBTLE_WAVE_LAYERS);
    drawWaveBand(ctx, time, width, height, baselineY, 0, COLORS.accentTeal, 0.10, phaseOffset, mouse, SUBTLE_WAVE_LAYERS);

    drawFoam(ctx, time, width, baselineY, phaseOffset, mouse, SUBTLE_WAVE_LAYERS);

    // Mouse ripple glow (muted for subtle dividers)
    drawMouseRipple(ctx, mouse, time, 0.6);
  } else {
    const baselineY = height * 0.45;

    // Back wave
    drawWaveBand(ctx, time, width, height, baselineY, -8, COLORS.cosmicPurple, 0.08, phaseOffset, mouse);

    // Mid wave
    drawWaveBand(ctx, time, width, height, baselineY, -3, COLORS.cosmicPurple, 0.06, phaseOffset + 0.5, mouse);
    drawWaveBand(ctx, time, width, height, baselineY, -3, COLORS.accentTeal, 0.08, phaseOffset + 0.5, mouse);

    // Front wave
    drawWaveBand(ctx, time, width, height, baselineY, 0, COLORS.accentTeal, 0.18, phaseOffset, mouse);

    // Foam
    drawFoam(ctx, time, width, baselineY, phaseOffset, mouse);

    // Mouse ripple glow
    drawMouseRipple(ctx, mouse, time);
  }
}

// ── Boat rendering ─────────────────────────────────────────

export function renderBoat(
  ctx: CanvasRenderingContext2D,
  boat: BoatState,
  time: number,
) {
  ctx.save();
  ctx.translate(boat.x, boat.y);
  ctx.rotate(boat.smoothTilt);

  const hw = BOAT_WIDTH / 2;
  const hullDepth = 13;
  const mastHeight = 36;
  const sailWidth = 18;

  // Water line shadow (subtle glow beneath hull)
  ctx.globalAlpha = 0.12;
  ctx.fillStyle = COLORS.accentTeal;
  ctx.beginPath();
  ctx.ellipse(0, hullDepth + 2, hw + 4, 4, 0, 0, Math.PI * 2);
  ctx.fill();

  // Hull body — curved shape
  ctx.beginPath();
  ctx.moveTo(-hw, -1);
  ctx.lineTo(-hw + 3, 0);
  ctx.quadraticCurveTo(-hw + 5, hullDepth, 0, hullDepth + 3);
  ctx.quadraticCurveTo(hw - 5, hullDepth, hw - 3, 0);
  ctx.lineTo(hw, -1);
  ctx.closePath();

  // Hull gradient
  const hullGrad = ctx.createLinearGradient(0, -2, 0, hullDepth + 3);
  hullGrad.addColorStop(0, "#f0e6d3"); // warm wood-like top
  hullGrad.addColorStop(0.5, "#c4a67a");
  hullGrad.addColorStop(1, "#8b6d47"); // darker bottom
  ctx.fillStyle = hullGrad;
  ctx.globalAlpha = 0.9;
  ctx.fill();

  // Hull rim highlight
  ctx.beginPath();
  ctx.moveTo(-hw + 4, 0);
  ctx.lineTo(hw - 4, 0);
  ctx.strokeStyle = "white";
  ctx.globalAlpha = 0.35;
  ctx.lineWidth = 1.2;
  ctx.stroke();

  // Hull bottom accent stripe
  ctx.beginPath();
  ctx.moveTo(-hw + 10, hullDepth * 0.7);
  ctx.quadraticCurveTo(0, hullDepth + 1, hw - 10, hullDepth * 0.7);
  ctx.strokeStyle = COLORS.cosmicPurple;
  ctx.globalAlpha = 0.3;
  ctx.lineWidth = 1.5;
  ctx.stroke();

  // Mast
  ctx.beginPath();
  ctx.moveTo(0, 0);
  ctx.lineTo(0, -mastHeight);
  ctx.strokeStyle = "#d4c5a9";
  ctx.globalAlpha = 0.8;
  ctx.lineWidth = 2;
  ctx.stroke();

  // Main sail — curved triangle with wind billowing
  const sailBillow = Math.sin(time * 1.5) * 2 + sailWidth;
  ctx.beginPath();
  ctx.moveTo(1, -mastHeight + 3);
  ctx.lineTo(1, -6);
  ctx.quadraticCurveTo(sailBillow * 0.7, -mastHeight * 0.45, sailBillow, -mastHeight * 0.4);
  ctx.quadraticCurveTo(sailBillow * 0.6, -mastHeight * 0.65, 1, -mastHeight + 3);
  ctx.closePath();

  const sailGrad = ctx.createLinearGradient(0, -mastHeight, sailBillow, -6);
  sailGrad.addColorStop(0, COLORS.accentTeal);
  sailGrad.addColorStop(1, COLORS.cosmicPurple);
  ctx.fillStyle = sailGrad;
  ctx.globalAlpha = 0.55;
  ctx.fill();

  // Sail seam lines
  ctx.strokeStyle = "white";
  ctx.globalAlpha = 0.1;
  ctx.lineWidth = 0.5;
  for (let i = 1; i <= 3; i++) {
    const t = i / 4;
    const sx = 1;
    const sy = -mastHeight + 3 + t * (mastHeight - 9);
    const ex = sailBillow * (0.3 + t * 0.4);
    const ey = -mastHeight * (0.65 - t * 0.25);
    ctx.beginPath();
    ctx.moveTo(sx, sy);
    ctx.lineTo(ex, ey);
    ctx.stroke();
  }

  // Flag at top — fluttering
  const flagWave = Math.sin(time * 4) * 3;
  ctx.beginPath();
  ctx.moveTo(0, -mastHeight);
  ctx.quadraticCurveTo(5 + flagWave, -mastHeight - 1, 10 + flagWave, -mastHeight + 2);
  ctx.lineTo(0, -mastHeight + 5);
  ctx.closePath();
  ctx.fillStyle = COLORS.cosmicPurple;
  ctx.globalAlpha = 0.75;
  ctx.fill();

  ctx.restore();
}

// ── Wake rendering ─────────────────────────────────────────

export function renderWake(
  ctx: CanvasRenderingContext2D,
  boat: BoatState,
) {
  if (boat.wakeParticles.length === 0) return;

  ctx.save();
  ctx.fillStyle = "white";

  for (const particle of boat.wakeParticles) {
    const life = 1 - particle.age;
    if (life <= 0) continue;

    ctx.globalAlpha = particle.opacity * life * 0.6;
    ctx.beginPath();
    ctx.arc(
      particle.x,
      particle.y,
      particle.radius * (0.5 + life * 0.5),
      0,
      Math.PI * 2,
    );
    ctx.fill();
  }

  ctx.restore();
}

// ── Boat physics update ────────────────────────────────────

export function updateBoat(
  boat: BoatState,
  time: number,
  canvasWidth: number,
  canvasHeight: number,
  dt: number,
  phaseOffset: number,
  mouse: MouseState | null,
  hasKeyboardInput: boolean,
): void {
  // Autonomous drift when no keyboard input
  if (!hasKeyboardInput) {
    boat.driftPhase += dt;

    // Gentle wandering — slow sine-based direction with occasional turns
    const driftWander =
      Math.sin(boat.driftPhase * 0.3) * 0.6 +
      Math.sin(boat.driftPhase * 0.13) * 0.4;
    boat.targetVx = driftWander * DRIFT_SPEED * boat.driftDirection;

    // Reverse direction when approaching edges
    const margin = BOAT_WIDTH + 40;
    if (boat.x < margin) boat.driftDirection = 1;
    else if (boat.x > canvasWidth - margin) boat.driftDirection = -1;
  }

  // Smooth velocity toward target
  boat.vx += (boat.targetVx - boat.vx) * BOAT_ACCEL_LERP;

  // Update position
  boat.x += boat.vx * dt * 60;

  // Clamp to bounds
  const boundsMargin = BOAT_WIDTH / 2 + 10;
  boat.x = Math.max(boundsMargin, Math.min(canvasWidth - boundsMargin, boat.x));

  // Track wave surface
  const baselineY = canvasHeight * 0.45;
  boat.y =
    baselineY +
    getWaveHeightWithMouse(boat.x, time, canvasWidth, mouse, WAVE_LAYERS, phaseOffset) +
    Math.sin(time * 3) * 1.5;

  // Compute and smooth tilt
  const rawTilt = Math.atan(
    getWaveSlope(boat.x, time, canvasWidth, mouse, WAVE_LAYERS, phaseOffset),
  );
  boat.tilt = Math.max(-MAX_TILT, Math.min(MAX_TILT, rawTilt));
  boat.smoothTilt += (boat.tilt - boat.smoothTilt) * TILT_LERP;

  // Wake intensity — always some wake when drifting, more when moving fast
  const speed = Math.abs(boat.vx);
  const moving = speed > 0.15;
  boat.wakeIntensity = moving
    ? Math.min(1, boat.wakeIntensity + 0.03)
    : Math.max(0, boat.wakeIntensity - 0.02);

  // Spawn wake particles
  if (moving && boat.wakeParticles.length < MAX_WAKE_PARTICLES) {
    const dir = boat.vx > 0 ? -1 : 1;
    boat.wakeParticles.push({
      x: boat.x + dir * (BOAT_WIDTH / 2) * 0.5,
      y: boat.y + 6,
      age: 0,
      opacity: 0.1 + Math.random() * 0.15,
      radius: 1.5 + Math.random() * 2.5,
      side: Math.random() > 0.5 ? 1 : -1,
    });
  }

  // Age and clean up wake particles
  for (let i = boat.wakeParticles.length - 1; i >= 0; i--) {
    const p = boat.wakeParticles[i];
    p.age += dt * 0.7;
    p.x += p.side * dt * 10;
    p.y += dt * 4;
    if (p.age >= 1) {
      boat.wakeParticles.splice(i, 1);
    }
  }
}

// ── Create initial boat state ──────────────────────────────

export function createBoatState(canvasWidth: number): BoatState {
  return {
    x: canvasWidth * 0.3 + Math.random() * canvasWidth * 0.4,
    vx: 0,
    targetVx: 0,
    y: 0,
    tilt: 0,
    smoothTilt: 0,
    wakeParticles: [],
    wakeIntensity: 0,
    driftPhase: Math.random() * 100, // random start so instances look different
    driftDirection: Math.random() > 0.5 ? 1 : -1,
  };
}
