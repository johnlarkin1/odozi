"use client";

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

const faqs = [
  {
    question: "Is Odyssey free?",
    answer:
      "Yes. Odyssey is completely free to download and use. There are no subscriptions, no in-app purchases, and no ads.",
  },
  {
    question: "Where is my data stored?",
    answer:
      "All your journal entries are stored locally on your device using SwiftData. If you enable the optional cloud backup, your data is end-to-end encrypted (AES-256-GCM) — meaning only you can read it.",
  },
  {
    question: "How long does a daily check-in take?",
    answer:
      "About 1–2 minutes. There are 8 gentle prompts, and every single one is skippable. You can write as much or as little as you like.",
  },
  {
    question: "Do I need an account?",
    answer:
      "No. Odyssey works fully without an account. You only need one if you want to enable cloud backup, and you can sign in with Apple or Google — no email/password required.",
  },
  {
    question: "Is there an Android version?",
    answer:
      "Not yet. Odyssey is currently iOS-only (iPhone, iOS 17+). An Android version isn't on the immediate roadmap, but it's something we'd love to explore in the future.",
  },
  {
    question: "Can I export my data?",
    answer:
      "Yes. You can export all your entries as a CSV file at any time from the Profile tab. Your data is yours.",
  },
];

function FAQItem({ question, answer }: { question: string; answer: string }) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="border-b border-white/10">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex w-full items-center justify-between py-6 text-left"
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

export function FAQSection() {
  return (
    <section id="faq" className="relative px-6 py-28">
      <div className="mx-auto max-w-3xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center"
        >
          <h2 className="text-4xl font-bold sm:text-5xl">
            Frequently asked{" "}
            <span className="text-accent-amber">questions.</span>
          </h2>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.15 }}
          className="mt-14"
        >
          {faqs.map((faq) => (
            <FAQItem key={faq.question} {...faq} />
          ))}
        </motion.div>
      </div>
    </section>
  );
}
