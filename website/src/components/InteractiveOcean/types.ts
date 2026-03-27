export interface WaveLayer {
  amplitude: number;
  frequency: number;
  speed: number;
  phase: number;
}

export interface WakeParticle {
  x: number;
  y: number;
  age: number;
  opacity: number;
  radius: number;
  side: 1 | -1; // left or right of wake V
}

export interface BoatState {
  x: number;
  vx: number;
  targetVx: number;
  y: number;
  tilt: number;
  smoothTilt: number;
  wakeParticles: WakeParticle[];
  wakeIntensity: number;
  // Autonomous drift
  driftPhase: number;
  driftDirection: 1 | -1;
}

export interface MouseState {
  x: number;
  y: number;
  active: boolean; // whether mouse is over the canvas
  lastMoveTime: number;
}

export interface OceanColors {
  deepSpace: string;
  cosmicPurple: string;
  accentTeal: string;
  starWhite: string;
}

export const COLORS: OceanColors = {
  deepSpace: "#0D0D1F",
  cosmicPurple: "#8C5CF5",
  accentTeal: "#2EC4B6",
  starWhite: "#EDF0FA",
};

export const WAVE_LAYERS: WaveLayer[] = [
  { amplitude: 18, frequency: 0.0025, speed: 0.4, phase: 0 },
  { amplitude: 12, frequency: 0.004, speed: 0.6, phase: 2.0 },
  { amplitude: 6, frequency: 0.008, speed: 1.0, phase: 4.5 },
  { amplitude: 3, frequency: 0.015, speed: 1.5, phase: 1.2 },
  { amplitude: 1.5, frequency: 0.025, speed: 2.0, phase: 3.0 },
];

export const BOAT_WIDTH = 50;
export const BOAT_HEIGHT = 55;
export const BOAT_SPEED = 3;
export const BOAT_ACCEL_LERP = 0.08;
export const TILT_LERP = 0.1;
export const MAX_TILT = (15 * Math.PI) / 180;
export const MAX_WAKE_PARTICLES = 40;
export const DRIFT_SPEED = 0.8; // autonomous drift speed
export const MOUSE_RIPPLE_RADIUS = 200; // how far mouse ripple extends
export const MOUSE_RIPPLE_STRENGTH = 25; // max displacement from mouse
