"use client";

import { motion } from "framer-motion";

const steps = [
  {
    number: "1",
    title: "Set Sail",
    description: "Open Odyssey and tap today's check-in to begin charting your course.",
    color: "text-accent-amber",
    bg: "bg-accent-amber/10",
    border: "border-accent-amber/30",
  },
  {
    number: "2",
    title: "Chart Your Course",
    description: "Navigate 8 gentle prompts — mood, gratitude, wins, tensions. Each one skippable.",
    color: "text-cosmic-purple",
    bg: "bg-cosmic-purple/10",
    border: "border-cosmic-purple/30",
  },
  {
    number: "3",
    title: "Navigate by Stars",
    description: "Over days and weeks, constellations of insight emerge from your journey.",
    color: "text-accent-teal",
    bg: "bg-accent-teal/10",
    border: "border-accent-teal/30",
  },
];

export function HowItWorks() {
  return (
    <section className="relative px-6 py-24">
      <div className="mx-auto max-w-4xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold sm:text-4xl">
            How it{" "}
            <span className="text-accent-teal">works.</span>
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-star-white/60">
            Less than two minutes a day. No account needed.
          </p>
        </motion.div>

        <div className="relative mt-16">
          {/* Connecting line — desktop only */}
          <div className="absolute left-0 right-0 top-12 hidden h-px bg-gradient-to-r from-accent-amber/40 via-cosmic-purple/40 to-accent-teal/40 md:block" />

          <div className="grid gap-8 md:grid-cols-3">
            {steps.map((step, i) => (
              <motion.div
                key={step.number}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.5, delay: i * 0.15 }}
                className="relative flex flex-col items-center text-center"
              >
                {/* Number circle */}
                <div
                  className={`flex h-12 w-12 items-center justify-center rounded-full border ${step.border} ${step.bg}`}
                >
                  <span className={`text-lg font-bold ${step.color}`}>{step.number}</span>
                </div>

                <h3 className="mt-5 text-lg font-semibold text-star-white">{step.title}</h3>
                <p className="mt-2 text-sm text-star-white/60">{step.description}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
