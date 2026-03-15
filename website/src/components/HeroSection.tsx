"use client";

import Image from "next/image";
import { motion } from "framer-motion";
import { CosmicBackground } from "./CosmicBackground";

const APP_STORE_URL = "https://apps.apple.com/app/odyssey-journal/id6743597741";

export function HeroSection() {
  return (
    <section className="relative flex min-h-[90vh] flex-col items-center justify-center overflow-hidden px-6 text-center">
      <CosmicBackground />

      <motion.div
        initial={{ opacity: 0, y: 30 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8 }}
        className="relative z-10 mx-auto max-w-3xl"
      >
        <h1 className="text-5xl font-bold leading-tight tracking-tight sm:text-7xl">
          <span className="bg-gradient-to-r from-accent-amber via-cosmic-purple to-accent-teal bg-clip-text text-transparent">
            Odyssey
          </span>
        </h1>

        <p className="mt-6 text-xl text-star-white/80 sm:text-2xl">
          Your daily journey inward.
        </p>

        <p className="mx-auto mt-4 max-w-lg text-base text-star-white/50">
          A guided journaling app that charts your world — location, health,
          screen time — and reveals constellations in your wellbeing.
        </p>

        <div className="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-full bg-star-white px-6 py-3 font-semibold text-deep-space transition hover:bg-star-white/90"
          >
            <svg className="h-5 w-5" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
            </svg>
            Download on the App Store
          </a>
        </div>
      </motion.div>

      {/* iPhone mockup with real screenshot */}
      <motion.div
        initial={{ opacity: 0, y: 50 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.3 }}
        className="relative z-10 mt-16"
      >
        <div className="mx-auto h-[500px] w-[250px] rounded-[40px] border-2 border-white/10 bg-card-surface/50 p-3 shadow-2xl backdrop-blur-sm">
          <div className="relative h-full w-full overflow-hidden rounded-[32px]">
            <Image
              src="/screenshots/today-tab.png"
              alt="Odyssey app — Today tab showing daily greeting, mood check-in, and health stats"
              fill
              className="object-cover object-top"
              priority
            />
          </div>
        </div>
      </motion.div>
    </section>
  );
}
