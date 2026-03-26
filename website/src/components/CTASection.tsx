"use client";

import { motion } from "framer-motion";
import { AnchorIcon, ShieldIcon, BanIcon } from "./Icons";

const APP_STORE_URL = "https://apps.apple.com/app/odyssey-journal/id6743597741";

export function PrivacySection() {
  return (
    <section className="relative px-6 py-28">
      <div className="mx-auto max-w-5xl text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
        >
          <h2 className="text-4xl font-bold sm:text-5xl">
            A safe harbor for{" "}
            <span className="text-success-green">your thoughts.</span>
          </h2>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-star-white/60">
            Odyssey is local-first. Your entries live on your device. Optional cloud backup
            uses end-to-end encryption (AES-256-GCM). No tracking. No ads. No data sales.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="mt-12 grid gap-6 sm:grid-cols-3"
        >
          {[
            { icon: <AnchorIcon className="text-success-green" />, title: "Anchored Locally", desc: "All data stored on your device by default" },
            { icon: <ShieldIcon className="text-success-green" />, title: "E2E Encrypted", desc: "Optional cloud backup that only you can read" },
            { icon: <BanIcon className="text-success-green" />, title: "No Tracking", desc: "Zero analytics (minus this marketing site), zero ads, zero data sharing" },
          ].map((item) => (
            <div key={item.title} className="rounded-2xl border border-white/10 bg-card-surface/50 p-7">
              <div>{item.icon}</div>
              <p className="mt-4 text-lg font-semibold text-star-white">{item.title}</p>
              <p className="mt-2 text-base text-star-white/60">{item.desc}</p>
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}

export function FinalCTASection() {
  return (
    <section className="relative overflow-hidden px-6 py-36">
      {/* Horizon wave */}
      <div className="pointer-events-none absolute inset-0" aria-hidden="true">
        <svg
          className="absolute bottom-0 left-0 w-full opacity-[0.08]"
          viewBox="0 0 1440 200"
          preserveAspectRatio="none"
          fill="none"
        >
          <path
            d="M0 100C360 40 720 160 1080 80C1260 40 1380 100 1440 100V200H0Z"
            fill="url(#cta-wave)"
          />
          <path
            d="M0 140C240 100 480 180 720 120C960 60 1200 160 1440 140V200H0Z"
            fill="url(#cta-wave)"
            opacity="0.5"
          />
          <defs>
            <linearGradient id="cta-wave" x1="0" y1="0" x2="1440" y2="0" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#8C5CF5" />
              <stop offset="50%" stopColor="#2EC4B6" />
              <stop offset="100%" stopColor="#8C5CF5" />
            </linearGradient>
          </defs>
        </svg>
      </div>
      <div className="relative mx-auto max-w-3xl text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
        >
          <h2 className="text-5xl font-bold sm:text-6xl">
            Set sail on your{" "}
            <span className="bg-gradient-to-r from-accent-amber via-cosmic-purple to-accent-teal bg-clip-text text-transparent">
              odyssey.
            </span>
          </h2>
          <p className="mt-5 text-xl text-star-white/60">
            Free to download. No account required. The horizon is waiting.
          </p>

          <div className="mt-8 flex flex-wrap items-center justify-center gap-x-8 gap-y-3 text-base text-star-white/50">
            <span className="flex items-center gap-2">
              <span className="inline-block h-2 w-2 rounded-full bg-success-green" />
              No account required
            </span>
            <span className="flex items-center gap-2">
              <span className="inline-block h-2 w-2 rounded-full bg-success-green" />
              No ads, ever
            </span>
            <span className="flex items-center gap-2">
              <span className="inline-block h-2 w-2 rounded-full bg-success-green" />
              No subscription
            </span>
          </div>

          <div className="mt-12">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-3 rounded-full bg-star-white px-10 py-5 text-xl font-semibold text-deep-space transition hover:bg-star-white/90"
            >
              <svg className="h-7 w-7" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
              </svg>
              Download on the App Store
            </a>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
