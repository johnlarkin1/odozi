"use client";

import { motion } from "framer-motion";
import { howItWorks } from "@/content";
import { renderInlineMarkdown } from "@/lib/renderInlineMarkdown";

export function HowItWorks() {
  return (
    <section className="relative px-6 py-28">
      <div className="mx-auto max-w-5xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="font-heading text-4xl font-bold sm:text-5xl">
            {howItWorks.heading}{" "}
            <span className="text-accent-teal">{howItWorks.headingAccent}</span>
          </h2>
          <p className="mx-auto mt-5 max-w-xl text-lg text-star-white/60">
            {howItWorks.subtitle}
          </p>
        </motion.div>

        <div className="relative mt-20">
          {/* Connecting line — desktop only */}
          <div className="absolute left-0 right-0 top-14 hidden h-px bg-gradient-to-r from-accent-amber/40 via-cosmic-purple/40 to-accent-teal/40 md:block" />

          <div className="grid gap-10 md:grid-cols-3">
            {howItWorks.steps.map((step, i) => (
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
                  className={`flex h-14 w-14 items-center justify-center rounded-full border-2 ${step.border} ${step.bg}`}
                >
                  <span className={`text-xl font-bold ${step.color}`}>{step.number}</span>
                </div>

                <h3 className="mt-6 text-xl font-semibold text-star-white">{step.title}</h3>
                <p className="mt-3 text-base text-star-white/60">{renderInlineMarkdown(step.description)}</p>
              </motion.div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
