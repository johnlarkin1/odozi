"use client";

import { useState, useEffect, useRef, useCallback, useSyncExternalStore } from "react";
import { useOceanSimulation } from "./useOceanSimulation";

interface InteractiveOceanProps {
  variant?: number;
  overlap?: boolean;
  interactive?: boolean;
}

const subscribeNoop = () => () => {};
const getIsTouch = () => "ontouchstart" in window || navigator.maxTouchPoints > 0;
const getIsTouchServer = () => false;

export function InteractiveOcean({ variant = 0, overlap = false, interactive = true }: InteractiveOceanProps) {
  const phaseOffset = variant * 2.5;
  const [showHint, setShowHint] = useState(false);
  const isTouch = useSyncExternalStore(subscribeNoop, getIsTouch, getIsTouchServer);
  const hintTimerRef = useRef<ReturnType<typeof setTimeout>>(undefined);
  const hintObserverRef = useRef<IntersectionObserver>(undefined);

  const hideHint = useCallback(() => {
    setShowHint(false);
    clearTimeout(hintTimerRef.current);
  }, []);

  const {
    canvasRef,
    containerRef,
    handleKeyDown,
    handleKeyUp,
    handleMouseMove,
    handleMouseLeave,
    handleTouchMove,
    handleTouchEnd,
  } = useOceanSimulation({
    phaseOffset,
    interactive,
    onFirstInteraction: interactive ? hideHint : undefined,
  });

  // Show hint when component enters viewport, auto-hide after 3s (interactive only)
  useEffect(() => {
    if (!interactive) return;
    const container = containerRef.current;
    if (!container) return;

    hintObserverRef.current = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setShowHint(true);
          hintTimerRef.current = setTimeout(() => setShowHint(false), 3000);
          hintObserverRef.current?.disconnect();
        }
      },
      { threshold: 0.5 },
    );
    hintObserverRef.current.observe(container);

    return () => {
      hintObserverRef.current?.disconnect();
      clearTimeout(hintTimerRef.current);
    };
  }, [containerRef, interactive]);

  return (
    <div
      ref={containerRef}
      className={`relative w-full overflow-hidden ${interactive ? "outline-none cursor-default focus-visible:ring-2 focus-visible:ring-accent-teal/50 focus-visible:ring-offset-0" : "pointer-events-none"} ${overlap ? "z-20" : ""}`}
      style={
        overlap
          ? { height: "180px", marginTop: "-40px", marginBottom: "-20px" }
          : interactive
            ? { height: "180px", marginTop: "-20px", marginBottom: "-20px" }
            : { height: "120px", marginTop: "-16px", marginBottom: "-16px" }
      }
      tabIndex={interactive ? 0 : undefined}
      role={interactive ? "img" : "presentation"}
      aria-label={interactive ? "Decorative animated ocean wave divider" : undefined}
      aria-hidden={!interactive || undefined}
      onKeyDown={interactive ? handleKeyDown : undefined}
      onKeyUp={interactive ? handleKeyUp : undefined}
      onMouseMove={interactive ? handleMouseMove : undefined}
      onMouseLeave={interactive ? handleMouseLeave : undefined}
      onTouchMove={interactive ? handleTouchMove : undefined}
      onTouchEnd={interactive ? handleTouchEnd : undefined}
    >
      <canvas
        ref={canvasRef}
        aria-hidden="true"
        className="block w-full h-full"
      />

      {/* Hint overlay (interactive only) */}
      {interactive && (
        <span
          aria-hidden="true"
          className={`absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2
            pointer-events-none select-none
            text-xs text-star-white/60 tracking-wide
            transition-opacity duration-700
            ${showHint ? "opacity-100" : "opacity-0"}`}
        >
          {isTouch ? "Tap and drag across the waves" : "Move your mouse over the waves"}
        </span>
      )}
    </div>
  );
}
