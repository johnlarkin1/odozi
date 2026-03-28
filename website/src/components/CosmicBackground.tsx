"use client";

export function CosmicBackground() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      {/* Gradient orbs */}
      <div className="absolute -top-40 left-1/4 h-[250px] w-[250px] rounded-full bg-cosmic-purple/20 blur-[80px] sm:h-[500px] sm:w-[500px] sm:blur-[120px]" />
      <div className="absolute -bottom-20 right-1/4 h-[200px] w-[200px] rounded-full bg-nebula-pink/15 blur-[60px] sm:h-[400px] sm:w-[400px] sm:blur-[100px]" />
      <div className="absolute left-1/2 top-1/3 h-[150px] w-[150px] rounded-full bg-accent-teal/10 blur-[50px] sm:h-[300px] sm:w-[300px] sm:blur-[80px]" />

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
