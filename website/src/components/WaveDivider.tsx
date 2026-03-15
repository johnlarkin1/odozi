export function WaveDivider({ flip = false }: { flip?: boolean }) {
  return (
    <div
      className={`pointer-events-none overflow-hidden ${flip ? "rotate-180" : ""}`}
      aria-hidden="true"
    >
      <svg
        className="w-full"
        viewBox="0 0 1440 48"
        preserveAspectRatio="none"
        fill="none"
        style={{ height: "48px" }}
      >
        <path
          d="M0 24C180 8 360 40 540 24C720 8 900 40 1080 24C1260 8 1380 32 1440 24V48H0Z"
          fill="url(#wave-divider)"
          opacity="0.06"
        />
        <defs>
          <linearGradient id="wave-divider" x1="0" y1="0" x2="1440" y2="0" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#8C5CF5" />
            <stop offset="50%" stopColor="#2EC4B6" />
            <stop offset="100%" stopColor="#8C5CF5" />
          </linearGradient>
        </defs>
      </svg>
    </div>
  );
}
