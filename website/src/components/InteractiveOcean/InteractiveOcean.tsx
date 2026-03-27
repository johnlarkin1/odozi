"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import { useOceanSimulation } from "./useOceanSimulation";

interface InteractiveOceanProps {
  variant?: number;
  overlap?: boolean;
}

export function InteractiveOcean({ variant = 0, overlap = false }: InteractiveOceanProps) {
  const phaseOffset = variant * 2.5;
  const [showHint, setShowHint] = useState(false);
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
  } = useOceanSimulation({
    phaseOffset,
    onFirstInteraction: hideHint,
  });

  // Show hint when component enters viewport, auto-hide after 3s
  useEffect(() => {
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
  }, [containerRef]);

  return (
    <div
      ref={containerRef}
      className={`relative w-full overflow-hidden outline-none cursor-default focus-visible:ring-2 focus-visible:ring-accent-teal/50 focus-visible:ring-offset-0 ${overlap ? "z-20" : ""}`}
      style={
        overlap
          ? { height: "180px", marginTop: "-40px", marginBottom: "-20px" }
          : { height: "180px", marginTop: "-20px", marginBottom: "-20px" }
      }
      tabIndex={0}
      role="img"
      aria-label="Decorative animated ocean wave divider"
      onKeyDown={handleKeyDown}
      onKeyUp={handleKeyUp}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
    >
      <canvas
        ref={canvasRef}
        aria-hidden="true"
        className="block w-full h-full"
      />

      {/* Hint overlay */}
      <span
        aria-hidden="true"
        className={`absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2
          pointer-events-none select-none
          text-xs text-star-white/60 tracking-wide
          transition-opacity duration-700
          ${showHint ? "opacity-100" : "opacity-0"}`}
      >
        Move your mouse over the waves
      </span>
    </div>
  );
}
