"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { faqs } from "@/content";
import { trackEvent } from "@/lib/analytics";

type FAQ = { question: string; answer: string };

type FAQSectionProps = {
  items?: readonly FAQ[];
  id?: string;
  heading?: string;
  headingAccent?: string;
};

function FAQItem({ question, answer }: FAQ) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="border-b border-white/10">
      <button
        onClick={() => { setIsOpen(!isOpen); trackEvent("faq_toggled", { question, is_open: !isOpen }); }}
        aria-expanded={isOpen}
        className="flex min-h-11 w-full items-center justify-between py-6 text-left"
      >
        <span className="pr-4 text-lg font-medium text-star-white">{question}</span>
        <motion.span
          animate={{ rotate: isOpen ? 45 : 0 }}
          transition={{ duration: 0.2 }}
          className="flex-shrink-0 text-2xl text-star-white/40"
        >
          +
        </motion.span>
      </button>

      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.25 }}
            className="overflow-hidden"
          >
            <p className="pb-6 text-base leading-relaxed text-star-white/60">{answer}</p>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export function FAQSection({
  items = faqs,
  id = "faq",
  heading = "Frequently asked",
  headingAccent = "questions.",
}: FAQSectionProps = {}) {
  return (
    <section id={id} className="relative px-6 py-28">
      <div className="mx-auto max-w-3xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="font-heading text-4xl font-bold sm:text-5xl">
            {heading}{" "}
            <span className="text-accent-amber">{headingAccent}</span>
          </h2>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.15 }}
          className="mt-14"
        >
          {items.map((faq) => (
            <FAQItem key={faq.question} {...faq} />
          ))}
        </motion.div>
      </div>
    </section>
  );
}
