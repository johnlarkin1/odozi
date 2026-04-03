"use client";

import { useSyncExternalStore } from "react";
import { useOceanSimulation } from "./useOceanSimulation";

interface InteractiveOceanProps {
  variant?: number;
  overlap?: boolean;
  showBoat?: boolean;
}

const subscribeNoop = () => () => {};
const getIsTouch = () => "ontouchstart" in window || navigator.maxTouchPoints > 0;
const getIsTouchServer = () => false;

export function InteractiveOcean({ variant = 0, overlap = false, showBoat = false }: InteractiveOceanProps) {
  const phaseOffset = variant * 2.5;
  const isTouch = useSyncExternalStore(subscribeNoop, getIsTouch, getIsTouchServer);

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
    showBoat,
    subtle: !showBoat,
  });

  return (
    <div
      ref={containerRef}
      className={`relative w-full overflow-hidden cursor-default outline-none ${overlap ? "z-20" : ""}`}
      style={
        overlap
          ? { height: "180px", marginTop: "-40px", marginBottom: "-20px" }
          : showBoat
            ? { height: "180px", marginTop: "-20px", marginBottom: "-20px" }
            : { height: "120px", marginTop: "-16px", marginBottom: "-16px" }
      }
      tabIndex={showBoat ? 0 : undefined}
      role={showBoat ? "img" : "presentation"}
      aria-label={showBoat ? "Decorative animated ocean wave divider" : undefined}
      aria-hidden={!showBoat || undefined}
      onKeyDown={showBoat ? handleKeyDown : undefined}
      onKeyUp={showBoat ? handleKeyUp : undefined}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >
      <canvas
        ref={canvasRef}
        aria-hidden="true"
        className="block w-full h-full"
      />

      {/* Persistent hint (boat divider only) */}
      {showBoat && (
        <span
          aria-hidden="true"
          className="absolute left-1/2 bottom-[20%] -translate-x-1/2
            pointer-events-none select-none
            text-xs text-star-white/40 tracking-wide"
        >
          {isTouch ? "Tap and drag across the waves" : "Click here, then use your arrow keys to move the boat"}
        </span>
      )}
    </div>
  );
}
