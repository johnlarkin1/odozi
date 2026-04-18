import type { Metadata } from "next";

export type { Metadata };

const BASE_URL = process.env.NEXT_PUBLIC_BASE_URL || "https://odozi.app";

const UNFURL_PATHS = {
  gif: "/unfurls/odozi/main.gif",
  mp4: "/unfurls/odozi/main.mp4",
  static: "/unfurls/odozi/main-static.png",
};

export function getPlatformSpecificImage(userAgent?: string): {
  url: string;
  type: string;
} {
  let imageUrl = `${BASE_URL}${UNFURL_PATHS.gif}`;
  let mimeType = "image/gif";

  if (userAgent) {
    const ua = userAgent.toLowerCase();

    // Discord — GIF
    if (ua.includes("discordbot") || ua.includes("discord")) {
      return { url: `${BASE_URL}${UNFURL_PATHS.gif}`, type: "image/gif" };
    }

    // Slack — GIF
    if (ua.includes("slackbot")) {
      return { url: `${BASE_URL}${UNFURL_PATHS.gif}`, type: "image/gif" };
    }

    // LinkedIn — GIF
    if (ua.includes("linkedin")) {
      return { url: `${BASE_URL}${UNFURL_PATHS.gif}`, type: "image/gif" };
    }

    // Twitter, Facebook, WhatsApp — static PNG
    if (
      ua.includes("twitterbot") ||
      ua.includes("facebookexternalhit") ||
      ua.includes("whatsapp")
    ) {
      imageUrl = `${BASE_URL}${UNFURL_PATHS.static}`;
      mimeType = "image/png";
    }

    // iMessage/iOS — static PNG (video handled separately via og:video)
    if (
      ua.includes("iphone") ||
      ua.includes("ipad") ||
      (ua.includes("applewebkit") &&
        (ua.includes("mobile") ||
          (ua.includes("safari") && !ua.includes("chrome"))))
    ) {
      imageUrl = `${BASE_URL}${UNFURL_PATHS.static}`;
      mimeType = "image/png";
    }
  }

  return { url: imageUrl, type: mimeType };
}

export function isIMessageUserAgent(userAgent?: string): boolean {
  if (!userAgent) return false;
  const ua = userAgent.toLowerCase();
  return (
    ua.includes("iphone") ||
    ua.includes("ipad") ||
    (ua.includes("applewebkit") &&
      (ua.includes("mobile") ||
        (ua.includes("safari") && !ua.includes("chrome"))))
  );
}
