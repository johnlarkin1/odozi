"use client";

import Image from "next/image";
import { useRef, useState, useCallback, useEffect } from "react";
import { motion } from "framer-motion";
import { CosmicBackground } from "./CosmicBackground";
import { APP_STORE_URL, GITHUB_URL, hero, screenshots } from "@/content";

export function HeroSection() {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [activeIndex, setActiveIndex] = useState(0);

  const scrollToIndex = useCallback((index: number, instant = false) => {
    const container = scrollRef.current;
    if (!container) return;
    const items = container.querySelectorAll("[data-carousel-item]");
    const el = items[index] as HTMLElement | undefined;
    if (!el) return;
    const scrollTarget = el.offsetLeft - container.clientWidth / 2 + el.clientWidth / 2;
    container.scrollTo({ left: scrollTarget, behavior: instant ? "instant" : "smooth" });
    setActiveIndex(index);
  }, []);

  useEffect(() => {
    requestAnimationFrame(() => scrollToIndex(0, true));
  }, [scrollToIndex]);

  const handleScroll = useCallback(() => {
    const container = scrollRef.current;
    if (!container) return;
    const items = container.querySelectorAll("[data-carousel-item]");
    const containerCenter = container.scrollLeft + container.clientWidth / 2;
    let closest = 0;
    let minDist = Infinity;
    items.forEach((item, i) => {
      const el = item as HTMLElement;
      const itemCenter = el.offsetLeft + el.clientWidth / 2;
      const dist = Math.abs(containerCenter - itemCenter);
      if (dist < minDist) {
        minDist = dist;
        closest = i;
      }
    });
    setActiveIndex(closest);
  }, []);

  return (
    <section
      className="relative grid"
      style={{
        height: "calc(100dvh - 57px - 140px)",
        gridTemplateRows: "auto 1fr auto",
        overflowX: "clip",
        overflowY: "hidden",
      }}
    >
      <CosmicBackground />

      {/* Row 1: Hero text */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.7 }}
        className="relative z-10 w-full px-6 pt-2 text-center sm:pt-4"
      >
        <h1 className="text-4xl font-bold leading-tight tracking-tight sm:text-7xl">
          <span className="bg-gradient-to-r from-accent-amber via-cosmic-purple to-accent-teal bg-clip-text text-transparent">
            {hero.title}
          </span>
        </h1>

        <p className="mt-1 text-lg text-star-white/80 sm:mt-2 sm:text-2xl">
          {hero.tagline}
        </p>

        <p className="mx-auto mt-1 max-w-xl text-sm text-star-white/60 sm:mt-2 sm:text-base">
          {hero.subtitle}
        </p>

        <div className="mt-3 flex flex-wrap items-center justify-center gap-3 sm:mt-4">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-full bg-star-white px-5 py-2.5 text-sm font-semibold text-deep-space transition hover:bg-star-white/90 sm:px-6 sm:py-3 sm:text-base"
          >
            <svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
            </svg>
            {hero.cta}
          </a>
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-full bg-star-white px-5 py-2.5 text-sm font-semibold text-deep-space transition hover:bg-star-white/90 sm:px-6 sm:py-3 sm:text-base"
          >
            <svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
            </svg>
            GitHub
          </a>
        </div>
      </motion.div>

      {/* Row 2: Carousel (1fr — fills remaining space) */}
      <motion.div
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.7, delay: 0.25 }}
        className="relative z-10 min-h-0 min-w-0 w-full pt-2 sm:pt-3"
      >
        <div
          ref={scrollRef}
          onScroll={handleScroll}
          className="flex h-full snap-x snap-mandatory items-center gap-4 overflow-x-auto px-[calc(50vw-120px)] sm:gap-6 sm:px-[calc(50vw-160px)] scrollbar-hide"
          style={{ scrollbarWidth: "none", msOverflowStyle: "none" }}
        >
          {screenshots.map((shot, i) => (
            <div
              key={shot.src}
              data-carousel-item
              className="flex h-full max-h-[55vh] flex-shrink-0 snap-center cursor-pointer items-center py-1"
              onClick={() => scrollToIndex(i)}
            >
              <div
                className={`h-full rounded-[36px] border-2 p-2 shadow-2xl backdrop-blur-sm transition-all duration-300 sm:rounded-[44px] sm:p-3 ${
                  activeIndex === i
                    ? "border-white/20 bg-card-surface/60 scale-100"
                    : "border-white/5 bg-card-surface/30 scale-[0.92] opacity-60"
                }`}
                style={{ aspectRatio: "9 / 19.5" }}
              >
                <div className="relative h-full w-full overflow-hidden rounded-[28px] sm:rounded-[36px]">
                  <Image
                    src={shot.src}
                    alt={shot.alt}
                    width={1320}
                    height={2868}
                    className="h-full w-full object-cover object-top"
                    priority={i <= 2}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>
      </motion.div>

      {/* Row 3: Dot labels */}
      <div className="relative z-10 flex items-center justify-center gap-2 py-2 sm:gap-3 sm:py-3">
        {screenshots.map((shot, i) => (
          <button
            key={shot.src}
            onClick={() => scrollToIndex(i)}
            className={`rounded-full px-2.5 py-1 text-xs font-medium transition-all duration-200 sm:px-3 sm:py-1.5 sm:text-sm ${
              activeIndex === i
                ? "bg-white/15 text-star-white"
                : "text-star-white/40 hover:text-star-white/60"
            }`}
          >
            {shot.label}
          </button>
        ))}
      </div>
    </section>
  );
}
