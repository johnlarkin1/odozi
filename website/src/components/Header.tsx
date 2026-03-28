"use client";

import Image from "next/image";
import Link from "next/link";
import { useState } from "react";
import { APP_STORE_URL } from "@/content";
import { trackEvent } from "@/lib/analytics";

function LogoMark() {
  return (
    <Image
      src="/app-icon.png"
      alt="Odyssey app icon"
      width={28}
      height={28}
      className="rounded-md"
    />
  );
}

export { LogoMark };

export function Header() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 border-b border-white/10 bg-deep-space/80 backdrop-blur-md">
      <nav className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
        <Link href="/" className="flex items-center gap-2 font-heading text-xl font-bold tracking-tight text-star-white">
          <LogoMark />
          Odyssey
        </Link>

        {/* Desktop nav */}
        <div className="hidden items-center gap-8 md:flex">
          <Link href="/#features" onClick={() => trackEvent("nav_clicked", { label: "Features", destination: "/#features" })} className="text-sm text-star-white/70 transition hover:text-accent-teal">
            Features
          </Link>
          <Link href="/#faq" onClick={() => trackEvent("nav_clicked", { label: "FAQ", destination: "/#faq" })} className="text-sm text-star-white/70 transition hover:text-accent-teal">
            FAQ
          </Link>
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noopener noreferrer"
            onClick={() => trackEvent("cta_clicked", { label: "app_store", location: "header" })}
            className="rounded-full bg-star-white px-4 py-2 text-sm font-semibold text-deep-space transition hover:bg-star-white/90"
          >
            Download
          </a>
        </div>

        {/* Mobile hamburger */}
        <button
          onClick={() => setMobileOpen(!mobileOpen)}
          className="flex min-h-11 min-w-11 flex-col items-center justify-center gap-1.5 md:hidden"
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
            <Link href="/#features" onClick={() => { setMobileOpen(false); trackEvent("nav_clicked", { label: "Features", destination: "/#features" }); }} className="py-3 text-star-white/70">
              Features
            </Link>
            <Link href="/#faq" onClick={() => { setMobileOpen(false); trackEvent("nav_clicked", { label: "FAQ", destination: "/#faq" }); }} className="py-3 text-star-white/70">
              FAQ
            </Link>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => trackEvent("cta_clicked", { label: "app_store", location: "header" })}
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
