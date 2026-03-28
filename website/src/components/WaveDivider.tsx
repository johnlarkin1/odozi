"use client";

import { useSyncExternalStore } from "react";
import { InteractiveOcean } from "./InteractiveOcean";

const subscribe = () => () => {};
const getCanvasSupport = () => typeof HTMLCanvasElement !== "undefined";
const getServerSnapshot = () => false;

export function WaveDivider({
  variant = 0,
  overlap = false,
  interactive = true,
}: {
  variant?: number;
  overlap?: boolean;
  interactive?: boolean;
}) {
  const canUseCanvas = useSyncExternalStore(subscribe, getCanvasSupport, getServerSnapshot);

  if (!canUseCanvas) return <StaticWaveDivider />;
  return <InteractiveOcean variant={variant} overlap={overlap} interactive={interactive} />;
}

/** Static SVG fallback for SSR and no-canvas environments */
function StaticWaveDivider() {
  return (
    <div
      className="pointer-events-none overflow-hidden"
      aria-hidden="true"
    >
      <svg
        className="w-full"
        viewBox="0 0 1440 200"
        preserveAspectRatio="none"
        fill="none"
        style={{ height: "180px" }}
      >
        <defs>
          <linearGradient id="wd-deep" x1="0" y1="0" x2="1440" y2="0" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#8C5CF5" />
            <stop offset="50%" stopColor="#2EC4B6" />
            <stop offset="100%" stopColor="#8C5CF5" />
          </linearGradient>
          <linearGradient id="wd-teal" x1="0" y1="0" x2="1440" y2="0" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#2EC4B6" />
            <stop offset="50%" stopColor="#8C5CF5" />
            <stop offset="100%" stopColor="#2EC4B6" />
          </linearGradient>
        </defs>
        <path
          d="M0 110 C120 85,280 130,420 95 C560 60,680 120,840 90 C1000 60,1160 115,1300 85 C1380 70,1420 95,1440 90 V200 H0 Z"
          fill="url(#wd-deep)"
          opacity="0.08"
        />
        <path
          d="M0 120 C80 100,160 135,300 105 C440 75,540 130,720 95 C900 60,1020 125,1160 90 C1300 55,1380 105,1440 100 V200 H0 Z"
          fill="url(#wd-teal)"
          opacity="0.15"
        />
      </svg>
    </div>
  );
}
