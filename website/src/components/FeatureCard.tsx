"use client";

import { motion } from "framer-motion";

interface FeatureCardProps {
  icon: string;
  title: string;
  description: string;
  delay?: number;
}

export function FeatureCard({ icon, title, description, delay = 0 }: FeatureCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-50px" }}
      transition={{ duration: 0.5, delay }}
      className="rounded-2xl border border-white/10 bg-card-surface/50 p-6 backdrop-blur-sm"
    >
      <div className="text-3xl">{icon}</div>
      <h3 className="mt-4 text-lg font-semibold text-star-white">{title}</h3>
      <p className="mt-2 text-sm leading-relaxed text-star-white/60">{description}</p>
    </motion.div>
  );
}
