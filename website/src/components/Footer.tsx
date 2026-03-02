import Link from "next/link";

export function Footer() {
  return (
    <footer className="border-t border-white/10 bg-deep-space">
      <div className="mx-auto max-w-6xl px-6 py-12">
        <div className="grid gap-8 sm:grid-cols-3">
          <div>
            <p className="text-lg font-bold text-star-white">Odyssey</p>
            <p className="mt-2 text-sm text-star-white/60">
              Your daily journey inward.
            </p>
          </div>

          <div className="flex flex-col gap-2 text-sm">
            <p className="font-semibold text-star-white">Links</p>
            <Link href="/privacy" className="text-star-white/60 transition hover:text-accent-teal">
              Privacy Policy
            </Link>
            <Link href="/terms" className="text-star-white/60 transition hover:text-accent-teal">
              Terms of Service
            </Link>
          </div>

          <div className="flex flex-col gap-2 text-sm">
            <p className="font-semibold text-star-white">Contact</p>
            <a href="mailto:john@johnjlarkin.com" className="text-star-white/60 transition hover:text-accent-teal">
              john@johnjlarkin.com
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
