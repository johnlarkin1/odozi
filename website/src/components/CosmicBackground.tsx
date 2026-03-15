"use client";

export function CosmicBackground() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      {/* Gradient orbs */}
      <div className="absolute -top-40 left-1/4 h-[500px] w-[500px] rounded-full bg-cosmic-purple/20 blur-[120px]" />
      <div className="absolute -bottom-20 right-1/4 h-[400px] w-[400px] rounded-full bg-nebula-pink/15 blur-[100px]" />
      <div className="absolute left-1/2 top-1/3 h-[300px] w-[300px] rounded-full bg-accent-teal/10 blur-[80px]" />

      {/* Starfield — scattered dots with twinkle animation */}
      <div className="absolute inset-0">
        <div className="star" style={{ top: "8%", left: "12%", animationDelay: "0s" }} />
        <div className="star" style={{ top: "15%", left: "67%", animationDelay: "1.2s" }} />
        <div className="star" style={{ top: "22%", left: "35%", animationDelay: "2.5s" }} />
        <div className="star" style={{ top: "5%", left: "82%", animationDelay: "0.7s" }} />
        <div className="star" style={{ top: "30%", left: "91%", animationDelay: "3.1s" }} />
        <div className="star" style={{ top: "12%", left: "48%", animationDelay: "1.8s" }} />
        <div className="star" style={{ top: "38%", left: "8%", animationDelay: "0.3s" }} />
        <div className="star" style={{ top: "25%", left: "55%", animationDelay: "2.1s" }} />
        <div className="star star-bright" style={{ top: "18%", left: "25%", animationDelay: "0.5s" }} />
        <div className="star star-bright" style={{ top: "10%", left: "75%", animationDelay: "2.8s" }} />
        <div className="star" style={{ top: "35%", left: "42%", animationDelay: "1.5s" }} />
        <div className="star" style={{ top: "28%", left: "18%", animationDelay: "3.4s" }} />
      </div>

      {/* Horizon wave — subtle ocean hint at the bottom */}
      <svg
        className="absolute bottom-0 left-0 w-full opacity-[0.06]"
        viewBox="0 0 1440 120"
        preserveAspectRatio="none"
        fill="none"
      >
        <path
          d="M0 60C240 20 480 100 720 60C960 20 1200 100 1440 60V120H0Z"
          fill="url(#wave-gradient)"
        />
        <defs>
          <linearGradient id="wave-gradient" x1="0" y1="0" x2="1440" y2="0" gradientUnits="userSpaceOnUse">
            <stop offset="0%" stopColor="#8C5CF5" />
            <stop offset="50%" stopColor="#2EC4B6" />
            <stop offset="100%" stopColor="#8C5CF5" />
          </linearGradient>
        </defs>
      </svg>
    </div>
  );
}

export function SectionStars() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      <div className="star" style={{ top: "20%", left: "5%", animationDelay: "0.4s" }} />
      <div className="star" style={{ top: "40%", left: "92%", animationDelay: "1.6s" }} />
      <div className="star" style={{ top: "70%", left: "15%", animationDelay: "2.3s" }} />
      <div className="star star-bright" style={{ top: "30%", left: "88%", animationDelay: "0.9s" }} />
      <div className="star" style={{ top: "60%", left: "95%", animationDelay: "3.0s" }} />
    </div>
  );
}
