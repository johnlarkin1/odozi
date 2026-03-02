export function CosmicBackground() {
  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      {/* Gradient orbs */}
      <div className="absolute -top-40 left-1/4 h-[500px] w-[500px] rounded-full bg-cosmic-purple/20 blur-[120px]" />
      <div className="absolute -bottom-20 right-1/4 h-[400px] w-[400px] rounded-full bg-nebula-pink/15 blur-[100px]" />
      <div className="absolute left-1/2 top-1/3 h-[300px] w-[300px] rounded-full bg-accent-teal/10 blur-[80px]" />
    </div>
  );
}
