"use client";

import Image from "next/image";
import Link from "next/link";
import { APP_STORE_URL, GITHUB_URL, footer } from "@/content";
import { trackEvent } from "@/lib/analytics";

export function Footer() {
  return (
    <footer className="border-t border-white/10 bg-deep-space">
      <div className="mx-auto max-w-6xl px-6 py-12">
        <div className="grid gap-8 sm:grid-cols-4">
          <div>
            <div className="flex items-center gap-2">
              <Image
                src="/app-icon.png"
                alt="Odyssey app icon"
                width={28}
                height={28}
                className="rounded-md"
              />
              <p className="text-lg font-bold text-star-white">Odyssey</p>
            </div>
            <p className="mt-2 text-sm text-star-white/60">
              {footer.tagline}
            </p>
            <p className="mt-3 text-xs text-star-white/40">
              {footer.madeIn}
            </p>
          </div>

          <div className="flex flex-col gap-2 text-sm">
            <p className="font-semibold text-star-white">Links</p>
            <Link href="/privacy" onClick={() => trackEvent("cta_clicked", { label: "privacy_policy", location: "footer" })} className="text-star-white/60 transition hover:text-accent-teal">
              Privacy Policy
            </Link>
            <Link href="/terms" onClick={() => trackEvent("cta_clicked", { label: "terms_of_service", location: "footer" })} className="text-star-white/60 transition hover:text-accent-teal">
              Terms of Service
            </Link>
            <Link href="/#faq" onClick={() => trackEvent("cta_clicked", { label: "faq", location: "footer" })} className="text-star-white/60 transition hover:text-accent-teal">
              FAQ
            </Link>
            <a href={GITHUB_URL} target="_blank" rel="noopener noreferrer" onClick={() => trackEvent("cta_clicked", { label: "github", location: "footer" })} className="text-star-white/60 transition hover:text-accent-teal">
              GitHub
            </a>
          </div>

          <div className="flex flex-col gap-2 text-sm">
            <p className="font-semibold text-star-white">Contact</p>
            <a href="mailto:john@odozi.app" onClick={() => trackEvent("cta_clicked", { label: "email_contact", location: "footer" })} className="text-star-white/60 transition hover:text-accent-teal">
              john@odozi.app
            </a>
          </div>

          <div className="flex flex-col gap-3 text-sm">
            <p className="font-semibold text-star-white">Download</p>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              onClick={() => trackEvent("cta_clicked", { label: "app_store", location: "footer" })}
              className="inline-flex w-fit items-center gap-2 rounded-lg border border-white/10 px-3 py-2 text-xs text-star-white/70 transition hover:border-white/20 hover:text-star-white"
            >
              <svg className="h-4 w-4" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
              </svg>
              App Store
            </a>
          </div>
        </div>

        <div className="mt-8 border-t border-white/10 pt-6 text-center text-xs text-star-white/40">
          &copy; {new Date().getFullYear()} Odyssey. All rights reserved.
        </div>
      </div>
    </footer>
  );
}
