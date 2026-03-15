"use client";

import Image from "next/image";
import { useRef, useState, useCallback } from "react";
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

const insightsList = [
  { icon: <TrendingUpIcon className="text-cosmic-purple" />, title: "Mood Trends", description: "Charts that show how your mood changes over weeks and months" },
  { icon: <CloudIcon className="text-cosmic-purple" />, title: "Word Cloud", description: "Your most-used journal words, beautifully visualized" },
  { icon: <FlameIcon className="text-cosmic-purple" />, title: "Streaks", description: "Build consistency with daily journaling streaks" },
  { icon: <MapIcon className="text-cosmic-purple" />, title: "Journey Map", description: "Color-coded mood pins on a map of where you've been" },
  { icon: <Link2Icon className="text-cosmic-purple" />, title: "Correlations", description: "See connections between sleep, steps, screen time, and mood" },
];

const screenshots = [
  { src: "/screenshots/today-tab.png", label: "Today", alt: "Today tab with daily greeting and health stats" },
  { src: "/screenshots/guided-journaling.png", label: "Journaling", alt: "Guided journaling flow with mood check-in" },
  { src: "/screenshots/insights-dashboard.png", label: "Insights", alt: "Insights dashboard with mood trends and streaks" },
  { src: "/screenshots/map-visualization.png", label: "Map", alt: "Journey map with color-coded mood pins" },
  { src: "/screenshots/word-cloud.png", label: "Word Cloud", alt: "Word cloud of most-used journal words" },
  { src: "/screenshots/year-in-review.png", label: "Year in Review", alt: "Spotify Wrapped-style year in review" },
];

export function ScreenshotCarousel() {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [activeIndex, setActiveIndex] = useState(0);

  const scrollToIndex = useCallback((index: number) => {
    const container = scrollRef.current;
    if (!container) return;
    const items = container.querySelectorAll("[data-carousel-item]");
    if (items[index]) {
      items[index].scrollIntoView({ behavior: "smooth", inline: "center", block: "nearest" });
      setActiveIndex(index);
    }
  }, []);

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
    <section className="relative py-28">
      <SectionStars />
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="text-4xl font-bold sm:text-5xl">
            See it in{" "}
            <span className="text-accent-teal">action.</span>
          </h2>
          <p className="mx-auto mt-5 max-w-xl text-lg text-star-white/60">
            Swipe through real screenshots from the app.
          </p>
        </motion.div>
      </div>

      {/* Carousel */}
      <motion.div
        initial={{ opacity: 0, y: 30 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6, delay: 0.2 }}
        className="mt-14"
      >
        <div
          ref={scrollRef}
          onScroll={handleScroll}
          className="flex snap-x snap-mandatory gap-6 overflow-x-auto px-[calc(50vw-160px)] pb-4 sm:px-[calc(50vw-190px)] scrollbar-hide"
          style={{ scrollbarWidth: "none", msOverflowStyle: "none" }}
        >
          {screenshots.map((shot, i) => (
            <div
              key={shot.src}
              data-carousel-item
              className="flex-shrink-0 snap-center cursor-pointer"
              onClick={() => scrollToIndex(i)}
            >
              <div
                className={`h-[640px] w-[320px] rounded-[44px] border-2 p-3 shadow-2xl backdrop-blur-sm transition-all duration-300 sm:h-[740px] sm:w-[370px] ${
                  activeIndex === i
                    ? "border-white/20 bg-card-surface/60 scale-100"
                    : "border-white/5 bg-card-surface/30 scale-95 opacity-60"
                }`}
              >
                <div className="relative h-full w-full overflow-hidden rounded-[34px]">
                  <Image
                    src={shot.src}
                    alt={shot.alt}
                    width={1320}
                    height={2868}
                    className="h-full w-full object-cover object-top"
                  />
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Dots + labels */}
        <div className="mt-8 flex items-center justify-center gap-3">
          {screenshots.map((shot, i) => (
            <button
              key={shot.src}
              onClick={() => scrollToIndex(i)}
              className={`rounded-full px-3 py-1.5 text-sm font-medium transition-all duration-200 ${
                activeIndex === i
                  ? "bg-white/15 text-star-white"
                  : "text-star-white/40 hover:text-star-white/60"
              }`}
            >
              {shot.label}
            </button>
          ))}
        </div>
      </motion.div>
    </section>
  );
}

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
          {insightsList.map((item, i) => (
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
      </div>
    </section>
  );
}
