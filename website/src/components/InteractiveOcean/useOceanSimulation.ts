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
  onFirstInteraction?: () => void;
}

export function useOceanSimulation({
  phaseOffset,
  onFirstInteraction,
}: UseOceanSimulationOptions) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const animFrameRef = useRef<number>(0);
  const timeRef = useRef(0);
  const lastFrameRef = useRef(0);
  const isVisibleRef = useRef(false);
  const boatRef = useRef<BoatState | null>(null);
  const keysRef = useRef({ left: false, right: false });
  const mouseRef = useRef<MouseState>({ x: 0, y: 0, active: false, lastMoveTime: 0 });
  const hasInteractedRef = useRef(false);
  const onFirstInteractionRef = useRef(onFirstInteraction);
  onFirstInteractionRef.current = onFirstInteraction;

  const setupCanvas = useCallback(() => {
    const canvas = canvasRef.current;
    const container = containerRef.current;
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

    if (!boatRef.current) {
      boatRef.current = createBoatState(rect.width);
    } else {
      boatRef.current.x = Math.min(boatRef.current.x, rect.width - 20);
    }
  }, []);

  const tick = useCallback(
    (timestamp: number) => {
      const canvas = canvasRef.current;
      if (!canvas) return;

      const ctx = canvas.getContext("2d");
      if (!ctx) return;

      if (lastFrameRef.current === 0) lastFrameRef.current = timestamp;
      const dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05);
      lastFrameRef.current = timestamp;
      timeRef.current += dt;

      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const width = canvas.width / dpr;
      const height = canvas.height / dpr;
      const time = timeRef.current;

      const mouse = mouseRef.current;
      const activeMouse = mouse.active ? mouse : null;

      // Update boat
      const boat = boatRef.current;
      if (boat) {
        const hasKeyboardInput = keysRef.current.left || keysRef.current.right;
        if (hasKeyboardInput) {
          boat.targetVx = keysRef.current.left
            ? -BOAT_SPEED
            : BOAT_SPEED;
        }
        updateBoat(boat, time, width, height, dt, phaseOffset, activeMouse, hasKeyboardInput);
      }

      // Render
      ctx.save();
      ctx.clearRect(0, 0, width, height);

      renderOcean(ctx, time, width, height, phaseOffset, activeMouse);

      if (boat) {
        renderWake(ctx, boat);
        renderBoat(ctx, boat, time);
      }

      ctx.restore();

      animFrameRef.current = requestAnimationFrame(tick);
    },
    [phaseOffset],
  );

  const startLoop = useCallback(() => {
    if (animFrameRef.current) return;
    lastFrameRef.current = 0;
    animFrameRef.current = requestAnimationFrame(tick);
  }, [tick]);

  const stopLoop = useCallback(() => {
    if (animFrameRef.current) {
      cancelAnimationFrame(animFrameRef.current);
      animFrameRef.current = 0;
    }
  }, []);

  // Keyboard handlers
  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
      e.preventDefault();
      if (e.key === "ArrowLeft") keysRef.current.left = true;
      if (e.key === "ArrowRight") keysRef.current.right = true;

      if (!hasInteractedRef.current) {
        hasInteractedRef.current = true;
        onFirstInteractionRef.current?.();
      }
    }
  }, []);

  const handleKeyUp = useCallback((e: React.KeyboardEvent) => {
    if (e.key === "ArrowLeft") keysRef.current.left = false;
    if (e.key === "ArrowRight") keysRef.current.right = false;
  }, []);

  // Mouse handlers
  const handleMouseMove = useCallback((e: React.MouseEvent) => {
    const container = containerRef.current;
    if (!container) return;
    const rect = container.getBoundingClientRect();
    mouseRef.current.x = e.clientX - rect.left;
    mouseRef.current.y = e.clientY - rect.top;
    mouseRef.current.active = true;
    mouseRef.current.lastMoveTime = timeRef.current;

    if (!hasInteractedRef.current) {
      hasInteractedRef.current = true;
      onFirstInteractionRef.current?.();
    }
  }, []);

  const handleMouseLeave = useCallback(() => {
    mouseRef.current.active = false;
  }, []);

  // Setup: canvas sizing, intersection observer, resize observer
  useEffect(() => {
    setupCanvas();

    const container = containerRef.current;
    if (!container) return;

    const io = new IntersectionObserver(
      ([entry]) => {
        isVisibleRef.current = entry.isIntersecting;
        if (entry.isIntersecting) {
          startLoop();
        } else {
          stopLoop();
        }
      },
      { threshold: 0 },
    );
    io.observe(container);

    let resizeTimeout: ReturnType<typeof setTimeout>;
    const ro = new ResizeObserver(() => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(setupCanvas, 100);
    });
    ro.observe(container);

    return () => {
      stopLoop();
      io.disconnect();
      ro.disconnect();
      clearTimeout(resizeTimeout);
    };
  }, [setupCanvas, startLoop, stopLoop]);

  return {
    canvasRef,
    containerRef,
    handleKeyDown,
    handleKeyUp,
    handleMouseMove,
    handleMouseLeave,
  };
}
