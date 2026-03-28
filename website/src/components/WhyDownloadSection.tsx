"use client";

import { motion } from "framer-motion";
import { whyDownload } from "@/content";
import { renderInlineMarkdown } from "@/lib/renderInlineMarkdown";

export function WhyDownloadSection() {
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
          <h2 className="font-heading text-3xl font-bold sm:text-4xl">
            {whyDownload.heading}
            <br />
            <span className="text-accent-amber">{whyDownload.headingAccent}</span>
          </h2>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.15 }}
          className="mt-10 space-y-6 text-lg leading-relaxed text-star-white/60"
        >
          {whyDownload.paragraphs.map((para, i) => (
            <p key={i}>{renderInlineMarkdown(para)}</p>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
