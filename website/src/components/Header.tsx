"use client";

import Link from "next/link";
import { useState } from "react";

const APP_STORE_URL = "https://apps.apple.com/app/odyssey-journal/id6743597741";

function LogoMark() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" className="flex-shrink-0">
      <defs>
        <linearGradient id="logo-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#F5A623" />
          <stop offset="50%" stopColor="#8C5CF5" />
          <stop offset="100%" stopColor="#2EC4B6" />
        </linearGradient>
      </defs>
      {/* Compass/star mark */}
      <circle cx="12" cy="12" r="10" stroke="url(#logo-gradient)" strokeWidth="1.5" />
      <path
        d="M12 2 L13.5 9.5 L12 8 L10.5 9.5 Z"
        fill="url(#logo-gradient)"
      />
      <path
        d="M12 22 L13.5 14.5 L12 16 L10.5 14.5 Z"
        fill="url(#logo-gradient)"
      />
      <path
        d="M2 12 L9.5 10.5 L8 12 L9.5 13.5 Z"
        fill="url(#logo-gradient)"
      />
      <path
        d="M22 12 L14.5 10.5 L16 12 L14.5 13.5 Z"
        fill="url(#logo-gradient)"
      />
      <circle cx="12" cy="12" r="2" fill="url(#logo-gradient)" />
    </svg>
  );
}

export { LogoMark };

export function Header() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 border-b border-white/10 bg-deep-space/80 backdrop-blur-md">
      <nav className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <Link href="/" className="flex items-center gap-2 text-xl font-bold tracking-tight text-star-white">
          <LogoMark />
          Odyssey
        </Link>

        {/* Desktop nav */}
        <div className="hidden items-center gap-8 md:flex">
          <Link href="/#features" className="text-sm text-star-white/70 transition hover:text-accent-teal">
            Features
          </Link>
          <Link href="/#faq" className="text-sm text-star-white/70 transition hover:text-accent-teal">
            FAQ
          </Link>
          <Link href="/privacy" className="text-sm text-star-white/70 transition hover:text-accent-teal">
            Privacy
          </Link>
          <Link href="/terms" className="text-sm text-star-white/70 transition hover:text-accent-teal">
            Terms
          </Link>
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            className="rounded-full bg-star-white px-4 py-2 text-sm font-semibold text-deep-space transition hover:bg-star-white/90"
          >
            Download
          </a>
        </div>

        {/* Mobile hamburger */}
        <button
          onClick={() => setMobileOpen(!mobileOpen)}
          className="flex flex-col gap-1.5 md:hidden"
          aria-label="Toggle menu"
        >
          <span className={`block h-0.5 w-6 bg-star-white transition ${mobileOpen ? "translate-y-2 rotate-45" : ""}`} />
          <span className={`block h-0.5 w-6 bg-star-white transition ${mobileOpen ? "opacity-0" : ""}`} />
          <span className={`block h-0.5 w-6 bg-star-white transition ${mobileOpen ? "-translate-y-2 -rotate-45" : ""}`} />
        </button>
      </nav>

      {/* Mobile menu */}
      {mobileOpen && (
        <div className="border-t border-white/10 bg-deep-space px-6 py-4 md:hidden">
          <div className="flex flex-col gap-4">
            <Link href="/#features" onClick={() => setMobileOpen(false)} className="text-star-white/70">
              Features
            </Link>
            <Link href="/#faq" onClick={() => setMobileOpen(false)} className="text-star-white/70">
              FAQ
            </Link>
            <Link href="/privacy" onClick={() => setMobileOpen(false)} className="text-star-white/70">
              Privacy
            </Link>
            <Link href="/terms" onClick={() => setMobileOpen(false)} className="text-star-white/70">
              Terms
            </Link>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="rounded-full bg-star-white px-4 py-2 text-center text-sm font-semibold text-deep-space"
            >
              Download
            </a>
          </div>
        </div>
      )}
    </header>
  );
}
