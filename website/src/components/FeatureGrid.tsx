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
import { howItWorks, whatYouTrack, whatYouGetBack, screenshots } from "@/content";
import { renderInlineMarkdown } from "@/lib/renderInlineMarkdown";

const promptIcons = [
  <SmileIcon key="smile" className="text-accent-amber" />,
  <PaletteIcon key="palette" className="text-accent-amber" />,
  <MoonIcon key="moon" className="text-accent-amber" />,
  <HeartIcon key="heart" className="text-accent-amber" />,
  <TrophyIcon key="trophy" className="text-accent-amber" />,
  <CloudLightningIcon key="cloud" className="text-accent-amber" />,
  <PenLineIcon key="pen" className="text-accent-amber" />,
  <WineIcon key="wine" className="text-accent-amber" />,
];

const backgroundIcons = [
  <MapPinIcon key="map-pin" className="text-accent-teal" />,
  <ActivityIcon key="activity" className="text-accent-teal" />,
  <SmartphoneIcon key="smartphone" className="text-accent-teal" />,
];

const insightsIcons = [
  <TrendingUpIcon key="trending" className="text-cosmic-purple" />,
  <CloudIcon key="cloud" className="text-cosmic-purple" />,
  <FlameIcon key="flame" className="text-cosmic-purple" />,
  <MapIcon key="map" className="text-cosmic-purple" />,
  <Link2Icon key="link" className="text-cosmic-purple" />,
  <FlameIcon key="yir" className="text-nebula-pink" />,
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
          <h2 className="font-heading text-4xl font-bold sm:text-5xl">
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
          className="flex snap-x snap-mandatory gap-6 overflow-x-auto px-[calc(50vw-140px)] pb-4 sm:px-[calc(50vw-190px)] scrollbar-hide"
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
                className={`h-[560px] w-[280px] rounded-[44px] border-2 p-3 shadow-2xl backdrop-blur-sm transition-all duration-300 sm:h-[640px] sm:w-[320px] ${
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
              className={`min-h-11 rounded-full px-3 py-1.5 text-sm font-medium transition-all duration-200 ${
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

export function WhatYouTrackSection() {
  return (
    <section id="features" className="relative px-6 py-28">
      <SectionStars />
      <div className="mx-auto max-w-6xl">
        {/* How it works */}
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

        <div className="relative mt-16">
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

        {/* What you track */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="mt-24 text-center"
        >
          <h2 className="font-heading text-4xl font-bold sm:text-5xl">
            {whatYouTrack.heading}{" "}
            <span className="text-accent-amber">{whatYouTrack.headingAccent}</span>
          </h2>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-star-white/60">
            {whatYouTrack.subtitle}
          </p>
        </motion.div>

        {/* Prompts grid */}
        <div className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {whatYouTrack.prompts.map((step, i) => (
            <FeatureCard
              key={step.title}
              icon={promptIcons[i]}
              title={step.title}
              description={step.description}
              delay={i * 0.05}
            />
          ))}
        </div>

        {/* Background data sub-section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="mt-16 text-center"
        >
          <p className="text-sm font-medium uppercase tracking-widest text-accent-teal/80">
            {whatYouTrack.backgroundLabel}
          </p>
        </motion.div>

        <div className="mt-6 grid gap-6 sm:grid-cols-3">
          {whatYouTrack.backgroundItems.map((item, i) => (
            <FeatureCard
              key={item.title}
              icon={backgroundIcons[i]}
              title={item.title}
              description={item.description}
              delay={i * 0.1}
            />
          ))}
        </div>
      </div>
    </section>
  );
}

export function WhatYouGetBackSection() {
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
          <h2 className="font-heading text-4xl font-bold sm:text-5xl">
            {whatYouGetBack.heading}{" "}
            <span className="text-cosmic-purple">{whatYouGetBack.headingAccent}</span>
          </h2>
          <p className="mx-auto mt-5 max-w-2xl text-lg text-star-white/60">
            {whatYouGetBack.subtitle}
          </p>
        </motion.div>

        <div className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {whatYouGetBack.items.map((item, i) => (
            <FeatureCard
              key={item.title}
              icon={insightsIcons[i]}
              title={item.title}
              description={item.description}
              delay={i * 0.08}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
