import { useRef, useEffect, useCallback } from "react";
import {
  renderOcean,
  renderBoat,
  renderWake,
  updateBoat,
  createBoatState,
} from "./waveEngine";
import { type BoatState, type MouseState, BOAT_SPEED } from "./types";

interface UseOceanSimulationOptions {
  phaseOffset: number;
  showBoat?: boolean;
  subtle?: boolean;
  onFirstInteraction?: () => void;
}

/** Mutable state bag read by the animation loop — lives outside React's render cycle */
interface SimulationState {
  phaseOffset: number;
  showBoat: boolean;
  subtle: boolean;
  onFirstInteraction?: () => void;
  canvas: HTMLCanvasElement | null;
  container: HTMLDivElement | null;
  animFrame: number;
  time: number;
  lastFrame: number;
  boat: BoatState | null;
  keys: { left: boolean; right: boolean };
  mouse: MouseState;
  hasInteracted: boolean;
}

function createSimulationState(): SimulationState {
  return {
    phaseOffset: 0,
    showBoat: false,
    subtle: false,
    onFirstInteraction: undefined,
    canvas: null,
    container: null,
    animFrame: 0,
    time: 0,
    lastFrame: 0,
    boat: null,
    keys: { left: false, right: false },
    mouse: { x: 0, y: 0, active: false, lastMoveTime: 0 },
    hasInteracted: false,
  };
}

function setupCanvas(state: SimulationState) {
  const { canvas, container } = state;
  if (!canvas || !container) return;

  const rect = container.getBoundingClientRect();
  const dpr = Math.min(window.devicePixelRatio || 1, 2);

  canvas.width = rect.width * dpr;
  canvas.height = rect.height * dpr;
  canvas.style.width = `${rect.width}px`;
  canvas.style.height = `${rect.height}px`;

  const ctx = canvas.getContext("2d");
  if (ctx) {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  if (state.showBoat) {
    if (!state.boat) {
      state.boat = createBoatState(rect.width);
    } else {
      state.boat.x = Math.min(state.boat.x, rect.width - 20);
    }
  }
}

function tick(state: SimulationState, timestamp: number) {
  const { canvas } = state;
  if (!canvas) return;

  const ctx = canvas.getContext("2d");
  if (!ctx) return;

  if (state.lastFrame === 0) state.lastFrame = timestamp;
  const dt = Math.min((timestamp - state.lastFrame) / 1000, 0.05);
  state.lastFrame = timestamp;
  state.time += dt;

  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const width = canvas.width / dpr;
  const height = canvas.height / dpr;
  const time = state.time;
  const { showBoat, subtle, phaseOffset } = state;

  const activeMouse = state.mouse.active ? state.mouse : null;

  // Lazily create boat if needed (props sync may arrive after initial setupCanvas)
  if (showBoat && !state.boat) {
    state.boat = createBoatState(width);
  }

  // Update boat (only when showBoat)
  const boat = showBoat ? state.boat : null;
  if (boat) {
    const hasKeyboardInput = state.keys.left || state.keys.right;
    if (hasKeyboardInput) {
      boat.targetVx = state.keys.left ? -BOAT_SPEED : BOAT_SPEED;
    }
    updateBoat(boat, time, width, height, dt, phaseOffset, activeMouse, hasKeyboardInput);
  }

  // Render
  ctx.save();
  ctx.clearRect(0, 0, width, height);
  renderOcean(ctx, time, width, height, phaseOffset, activeMouse, subtle);

  if (boat) {
    renderWake(ctx, boat);
    renderBoat(ctx, boat, time);
  }

  ctx.restore();

  state.animFrame = requestAnimationFrame((ts) => tick(state, ts));
}

function startLoop(state: SimulationState) {
  if (state.animFrame) return;
  state.lastFrame = 0;
  state.animFrame = requestAnimationFrame((ts) => tick(state, ts));
}

function stopLoop(state: SimulationState) {
  if (state.animFrame) {
    cancelAnimationFrame(state.animFrame);
    state.animFrame = 0;
  }
}

export function useOceanSimulation({
  phaseOffset,
  showBoat = false,
  subtle = false,
  onFirstInteraction,
}: UseOceanSimulationOptions) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const stateRef = useRef<SimulationState>(undefined);
  if (stateRef.current === undefined) {
    stateRef.current = createSimulationState();
  }

  // Sync props into the mutable state bag via effect (React Compiler safe)
  useEffect(() => {
    const s = stateRef.current!;
    s.phaseOffset = phaseOffset;
    s.showBoat = showBoat;
    s.subtle = subtle;
    s.onFirstInteraction = onFirstInteraction;
  }, [phaseOffset, showBoat, subtle, onFirstInteraction]);

  // Setup: canvas sizing, intersection observer, resize observer
  useEffect(() => {
    const s = stateRef.current!;
    s.canvas = canvasRef.current;
    s.container = containerRef.current;
    setupCanvas(s);

    const container = s.container;
    if (!container) return;

    const io = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          startLoop(s);
        } else {
          stopLoop(s);
        }
      },
      { threshold: 0 },
    );
    io.observe(container);

    let resizeTimeout: ReturnType<typeof setTimeout>;
    const ro = new ResizeObserver(() => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => setupCanvas(s), 100);
    });
    ro.observe(container);

    return () => {
      stopLoop(s);
      io.disconnect();
      ro.disconnect();
      clearTimeout(resizeTimeout);
    };
  }, []);

  // Keyboard handlers
  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    const s = stateRef.current!;
    if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
      e.preventDefault();
      if (e.key === "ArrowLeft") s.keys.left = true;
      if (e.key === "ArrowRight") s.keys.right = true;

      if (!s.hasInteracted) {
        s.hasInteracted = true;
        s.onFirstInteraction?.();
      }
    }
  }, []);

  const handleKeyUp = useCallback((e: React.KeyboardEvent) => {
    const s = stateRef.current!;
    if (e.key === "ArrowLeft") s.keys.left = false;
    if (e.key === "ArrowRight") s.keys.right = false;
  }, []);

  // Mouse handlers
  const handleMouseMove = useCallback((e: React.MouseEvent) => {
    const s = stateRef.current!;
    const container = s.container;
    if (!container) return;
    const rect = container.getBoundingClientRect();
    s.mouse.x = e.clientX - rect.left;
    s.mouse.y = e.clientY - rect.top;
    s.mouse.active = true;
    s.mouse.lastMoveTime = s.time;

    if (!s.hasInteracted) {
      s.hasInteracted = true;
      s.onFirstInteraction?.();
    }
  }, []);

  const handleMouseLeave = useCallback(() => {
    stateRef.current!.mouse.active = false;
  }, []);

  // Touch handlers
  const handleTouchMove = useCallback((e: React.TouchEvent) => {
    const s = stateRef.current!;
    const container = s.container;
    if (!container) return;
    const touch = e.touches[0];
    const rect = container.getBoundingClientRect();
    s.mouse.x = touch.clientX - rect.left;
    s.mouse.y = touch.clientY - rect.top;
    s.mouse.active = true;
    s.mouse.lastMoveTime = s.time;

    if (!s.hasInteracted) {
      s.hasInteracted = true;
      s.onFirstInteraction?.();
    }
  }, []);

  const handleTouchEnd = useCallback(() => {
    stateRef.current!.mouse.active = false;
  }, []);

  return {
    canvasRef,
    containerRef,
    handleKeyDown,
    handleKeyUp,
    handleMouseMove,
    handleMouseLeave,
    handleTouchMove,
    handleTouchEnd,
  };
}
