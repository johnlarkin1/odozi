export function WaveDivider({ flip = false }: { flip?: boolean }) {
  return (
    <div
      className={`pointer-events-none overflow-hidden ${flip ? "rotate-180" : ""}`}
      aria-hidden="true"
    >
      <svg
        className="w-full"
        viewBox="0 0 1440 100"
        preserveAspectRatio="none"
        fill="none"
        style={{ height: "80px" }}
      >
        {/* Back wave — wider, more subtle */}
        <path
          d="M0 60C120 40 240 80 480 50C720 20 960 70 1200 45C1320 32 1400 55 1440 50V100H0Z"
          fill="url(#wave-back)"
          opacity="0.04"
        />
        {/* Mid wave */}
        <path
          d="M0 65C200 45 400 85 600 55C800 25 1000 75 1200 50C1340 35 1420 60 1440 55V100H0Z"
          fill="url(#wave-mid)"
          opacity="0.07"
        />
        {/* Front wave — sharpest */}
        <path
          d="M0 70C160 50 320 90 540 60C760 30 980 80 1140 55C1300 35 1400 65 1440 60V100H0Z"
          fill="url(#wave-front)"
          opacity="0.10"
        />
        <defs>
          <linearGradient id="wave-back" x1="0" y1="0" x2="1440" y2="0" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#8C5CF5" />
            <stop offset="100%" stopColor="#2EC4B6" />
          </linearGradient>
          <linearGradient id="wave-mid" x1="0" y1="0" x2="1440" y2="0" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#2EC4B6" />
            <stop offset="50%" stopColor="#8C5CF5" />
            <stop offset="100%" stopColor="#2EC4B6" />
          </linearGradient>
          <linearGradient id="wave-front" x1="0" y1="0" x2="1440" y2="0" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#8C5CF5" />
            <stop offset="50%" stopColor="#2EC4B6" />
            <stop offset="100%" stopColor="#8C5CF5" />
          </linearGradient>
        </defs>
      </svg>
    </div>
  );
}
