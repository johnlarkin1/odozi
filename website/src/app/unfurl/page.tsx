"use client";

import React, { useEffect } from "react";
import Link from "next/link";
import { UnfurlCanvas } from "@/components/unfurl/UnfurlCanvas";

const isProduction = process.env.NODE_ENV === "production";

export default function UnfurlPreviewPage() {
  // Hide cursor for clean recording
  useEffect(() => {
    const style = document.createElement("style");
    style.id = "unfurl-cursor-hide";
    style.textContent = `
      * { cursor: none !important; }
      body { overflow: hidden; }
    `;
    document.head.appendChild(style);
    return () => {
      const el = document.getElementById("unfurl-cursor-hide");
      if (el) document.head.removeChild(el);
    };
  }, []);

  if (isProduction) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-deep-space">
        <div className="text-center font-sans text-star-white">
          <p className="text-xl">This page is only available in development.</p>
          <Link
            href="/"
            className="mt-4 inline-block text-accent-teal hover:underline"
          >
            Go home
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-8 bg-gray-900 p-8">
      <div className="max-w-xl text-center font-sans text-sm text-gray-400">
        <h1 className="mb-4 text-xl text-white">Unfurl Preview</h1>
        <p className="mb-2">
          This canvas is exactly <strong>1200x630 pixels</strong> — the standard
          Open Graph size.
        </p>
        <p className="mb-2">
          Use a screen recorder (Cap, Kap, or Cmd+Shift+5) to capture a 3-5
          second loop, then run{" "}
          <code className="rounded bg-gray-800 px-1.5 py-0.5 text-accent-teal">
            npm run generate:unfurl
          </code>{" "}
          to create all asset formats.
        </p>
        <p className="text-accent-amber">
          Place recordings in{" "}
          <code className="rounded bg-gray-800 px-1.5 py-0.5">
            public/unfurls/
          </code>
        </p>
      </div>

      {/* The actual unfurl canvas at exact OG dimensions */}
      <div
        className="overflow-hidden rounded-lg shadow-2xl"
        style={{ width: "1200px", height: "630px", border: "2px solid #333" }}
      >
        <UnfurlCanvas />
      </div>

      <div className="font-mono text-xs text-gray-500">1200 x 630 px</div>
    </div>
  );
}
