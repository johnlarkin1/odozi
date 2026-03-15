"use client";

import { motion } from "framer-motion";
import { FeatureCard } from "./FeatureCard";
import { SectionStars } from "./CosmicBackground";
import {
  SmileIcon,
  PaletteIcon,
  MoonIcon,
  HeartIcon,
  TrophyIcon,
  CloudLightningIcon,
  PenLineIcon,
  WineIcon,
  MapPinIcon,
  ActivityIcon,
  SmartphoneIcon,
  TrendingUpIcon,
  CloudIcon,
  FlameIcon,
  MapIcon,
  Link2Icon,
} from "./Icons";

const journalingSteps = [
  { icon: <SmileIcon className="text-accent-amber" />, title: "Mood", description: "Rate how you're feeling on a simple scale" },
  { icon: <PaletteIcon className="text-accent-amber" />, title: "Feeling", description: "Pick a word and color that match your emotion" },
  { icon: <MoonIcon className="text-accent-amber" />, title: "Sleep", description: "Log how well you slept last night" },
  { icon: <HeartIcon className="text-accent-amber" />, title: "Gratitude", description: "Name something you're grateful for" },
  { icon: <TrophyIcon className="text-accent-amber" />, title: "Win", description: "Celebrate a small or big win today" },
  { icon: <CloudLightningIcon className="text-accent-amber" />, title: "Tension", description: "Acknowledge what's weighing on you" },
  { icon: <PenLineIcon className="text-accent-amber" />, title: "Journal", description: "Free-write whatever's on your mind" },
  { icon: <WineIcon className="text-accent-amber" />, title: "Drinks", description: "Track your alcohol consumption" },
];

const passiveCapture = [
  {
    icon: <MapPinIcon className="text-accent-teal" />,
    title: "Location",
    description: "A single GPS snapshot, reverse-geocoded to city and state. No continuous tracking.",
  },
  {
    icon: <ActivityIcon className="text-accent-teal" />,
    title: "Health",
    description: "Steps, walking distance, and sleep analysis from HealthKit — with your permission.",
  },
  {
    icon: <SmartphoneIcon className="text-accent-teal" />,
    title: "Screen Time",
    description: "Total screen time and pickups via the DeviceActivity framework.",
  },
];

const insights = [
  { icon: <TrendingUpIcon className="text-cosmic-purple" />, title: "Mood Trends", description: "Charts that show how your mood changes over weeks and months" },
  { icon: <CloudIcon className="text-cosmic-purple" />, title: "Word Cloud", description: "Your most-used journal words, beautifully visualized" },
  { icon: <FlameIcon className="text-cosmic-purple" />, title: "Streaks", description: "Build consistency with daily journaling streaks" },
  { icon: <MapIcon className="text-cosmic-purple" />, title: "Journey Map", description: "Color-coded mood pins on a map of where you've been" },
  { icon: <Link2Icon className="text-cosmic-purple" />, title: "Correlations", description: "See connections between sleep, steps, screen time, and mood" },
];

export function GuidedJournalingSection() {
  return (
    <section id="features" className="relative px-6 py-28">
      <SectionStars />
      <div className="mx-auto max-w-6xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="text-4xl font-bold sm:text-5xl">
            Eight gentle prompts.{" "}
            <span className="text-accent-amber">One daily voyage.</span>
          </h2>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-star-white/60">
            Odyssey guides you through a short daily check-in. Every step is skippable — no pressure, just presence.
          </p>
        </motion.div>

        <div className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
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
    <section className="relative px-6 py-28">
      <SectionStars />
      <div className="mx-auto max-w-6xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="text-4xl font-bold sm:text-5xl">
            While you journal,{" "}
            <span className="text-accent-teal">Odyssey reads the stars.</span>
          </h2>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-star-white/60">
            Background data capture charts the waters around you — no extra effort required.
          </p>
        </motion.div>

        <div className="mt-14 grid gap-6 sm:grid-cols-3">
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
    <section className="relative px-6 py-28">
      <SectionStars />
      <div className="mx-auto max-w-6xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="text-4xl font-bold sm:text-5xl">
            Constellations{" "}
            <span className="text-cosmic-purple">emerge.</span>
          </h2>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-star-white/60">
            Like stars forming patterns in the night sky, Odyssey reveals connections between your mood, habits, and the world around you.
          </p>
        </motion.div>

        <div className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
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
    <section className="relative px-6 py-28">
      <div className="mx-auto max-w-4xl text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
        >
          <h2 className="text-4xl font-bold sm:text-5xl">
            Your year.{" "}
            <span className="text-nebula-pink">Wrapped.</span>
          </h2>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-star-white/60">
            A Spotify Wrapped-style captain&apos;s log of your year — moods, streaks,
            top feelings, and more, beautifully charted into shareable cards.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="mt-14 flex justify-center"
        >
          <div className="mx-auto h-[560px] w-[280px] rounded-[40px] border-2 border-white/10 bg-card-surface/50 p-3 shadow-2xl backdrop-blur-sm sm:h-[640px] sm:w-[320px]">
            <div className="relative h-full w-full overflow-hidden rounded-[32px]">
              <img
                src="/screenshots/year-in-review.png"
                alt="Odyssey Year in Review — Your 2026 Odyssey with animated globe"
                className="h-full w-full object-cover object-top"
              />
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
