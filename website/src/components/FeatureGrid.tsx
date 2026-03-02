"use client";

import { motion } from "framer-motion";
import { FeatureCard } from "./FeatureCard";

const journalingSteps = [
  { icon: "😊", title: "Mood", description: "Rate how you're feeling on a simple scale" },
  { icon: "🎨", title: "Feeling", description: "Pick a word and color that match your emotion" },
  { icon: "😴", title: "Sleep", description: "Log how well you slept last night" },
  { icon: "🙏", title: "Gratitude", description: "Name something you're grateful for" },
  { icon: "🏆", title: "Win", description: "Celebrate a small or big win today" },
  { icon: "😤", title: "Tension", description: "Acknowledge what's weighing on you" },
  { icon: "📝", title: "Journal", description: "Free-write whatever's on your mind" },
  { icon: "🍷", title: "Drinks", description: "Track your alcohol consumption" },
];

const passiveCapture = [
  {
    icon: "📍",
    title: "Location",
    description: "A single GPS snapshot, reverse-geocoded to city and state. No continuous tracking.",
  },
  {
    icon: "🏃",
    title: "Health",
    description: "Steps, walking distance, and sleep analysis from HealthKit — with your permission.",
  },
  {
    icon: "📱",
    title: "Screen Time",
    description: "Total screen time and pickups via the DeviceActivity framework.",
  },
];

const insights = [
  { icon: "📈", title: "Mood Trends", description: "Charts that show how your mood changes over weeks and months" },
  { icon: "☁️", title: "Word Cloud", description: "Your most-used journal words, beautifully visualized" },
  { icon: "🔥", title: "Streaks", description: "Build consistency with daily journaling streaks" },
  { icon: "🗺️", title: "Journey Map", description: "Color-coded mood pins on a map of where you've been" },
  { icon: "🔗", title: "Correlations", description: "See connections between sleep, steps, screen time, and mood" },
];

export function GuidedJournalingSection() {
  return (
    <section id="features" className="relative px-6 py-24">
      <div className="mx-auto max-w-6xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold sm:text-4xl">
            Eight gentle prompts.{" "}
            <span className="text-accent-amber">One meaningful habit.</span>
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-star-white/60">
            Odyssey guides you through a short daily check-in. Every step is skippable — no pressure, just presence.
          </p>
        </motion.div>

        <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {journalingSteps.map((step, i) => (
            <FeatureCard key={step.title} {...step} delay={i * 0.05} />
          ))}
        </div>
      </div>
    </section>
  );
}

export function PassiveCaptureSection() {
  return (
    <section className="relative px-6 py-24">
      <div className="mx-auto max-w-6xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold sm:text-4xl">
            While you journal,{" "}
            <span className="text-accent-teal">Odyssey listens.</span>
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-star-white/60">
            Background data capture enriches your entries without any extra effort.
          </p>
        </motion.div>

        <div className="mt-12 grid gap-6 sm:grid-cols-3">
          {passiveCapture.map((item, i) => (
            <FeatureCard key={item.title} {...item} delay={i * 0.1} />
          ))}
        </div>
      </div>
    </section>
  );
}

export function InsightsSection() {
  return (
    <section className="relative px-6 py-24">
      <div className="mx-auto max-w-6xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="text-3xl font-bold sm:text-4xl">
            Patterns{" "}
            <span className="text-cosmic-purple">emerge.</span>
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-star-white/60">
            Odyssey reveals connections between your mood, habits, and the world around you.
          </p>
        </motion.div>

        <div className="mt-12 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {insights.map((item, i) => (
            <FeatureCard key={item.title} {...item} delay={i * 0.08} />
          ))}
        </div>
      </div>
    </section>
  );
}

export function YearInReviewSection() {
  return (
    <section className="relative px-6 py-24">
      <div className="mx-auto max-w-4xl text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
        >
          <h2 className="text-3xl font-bold sm:text-4xl">
            Your year.{" "}
            <span className="text-nebula-pink">Wrapped.</span>
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-star-white/60">
            A Spotify Wrapped-style year-in-review with shareable cards — your moods, streaks,
            top feelings, and more, beautifully presented.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="mt-12 grid gap-4 sm:grid-cols-3"
        >
          {["Mood Journey", "Top Feelings", "Streak Record"].map((label) => (
            <div
              key={label}
              className="flex h-48 items-center justify-center rounded-2xl border border-white/10 bg-gradient-to-br from-cosmic-purple/20 to-nebula-pink/20"
            >
              <p className="text-sm text-star-white/40">{label}</p>
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
