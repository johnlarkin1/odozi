import type { Metadata } from "next";
import { headers } from "next/headers";
import { Geist, Geist_Mono, Space_Grotesk } from "next/font/google";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import { PostHogProvider } from "@/components/PostHogProvider";
import { MotionConfigProvider } from "@/components/MotionConfigProvider";
import { getPlatformSpecificImage, isIMessageUserAgent } from "./metadata";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

const spaceGrotesk = Space_Grotesk({
  variable: "--font-space-grotesk",
  subsets: ["latin"],
});

const BASE_URL = "https://odozi.app";
const APP_STORE_ID = "6760240423";
const TITLE = "Odozi · Mood Journal — Sleep, Gratitude & Screen Time";
const SOCIAL_TITLE = "Odozi · Mood Journal";
const DESCRIPTION =
  "Odozi is a private mood journal for iOS. Track gratitude, sleep, screen time, and daily patterns in about two minutes a day. Local-first, no ads, no tracking.";

export async function generateMetadata(): Promise<Metadata> {
  const headersList = await headers();
  const userAgent = headersList.get("user-agent") || "";
  const image = getPlatformSpecificImage(userAgent);
  const isIMessage = isIMessageUserAgent(userAgent);

  return {
    title: TITLE,
    description: DESCRIPTION,
    metadataBase: new URL(BASE_URL),
    alternates: {
      canonical: "/",
    },
    openGraph: {
      title: SOCIAL_TITLE,
      description: DESCRIPTION,
      url: BASE_URL,
      siteName: "Odozi",
      images: [
        {
          url: image.url,
          width: 1200,
          height: 630,
          alt: "Odozi — Your daily journey inward",
          type: image.type,
        },
      ],
      type: isIMessage ? "video.other" : "website",
    },
    twitter: {
      card: "summary_large_image",
      title: SOCIAL_TITLE,
      description: DESCRIPTION,
      images: [`${BASE_URL}/unfurls/odozi/main-static.png`],
      creator: "@johnlarkin1",
    },
    icons: {
      icon: [
        { url: "/favicon-48x48.png", sizes: "48x48", type: "image/png" },
        { url: "/favicon-32x32.png", sizes: "32x32", type: "image/png" },
        { url: "/favicon-16x16.png", sizes: "16x16", type: "image/png" },
        { url: "/favicon.svg", type: "image/svg+xml" },
      ],
      apple: "/apple-touch-icon.png",
    },
    other: {
      // iOS Smart App Banner — surfaces a native "Open in App Store" banner
      // on Safari and is part of how Apple associates this site with the app.
      "apple-itunes-app": `app-id=${APP_STORE_ID}`,

      // iMessage: serve MP4 video for inline playback
      ...(isIMessage
        ? {
            "og:video": `${BASE_URL}/unfurls/odozi/main.mp4`,
            "og:video:secure_url": `${BASE_URL}/unfurls/odozi/main.mp4`,
            "og:video:type": "video/mp4",
            "og:video:width": "1200",
            "og:video:height": "630",
          }
        : {}),

      // Discord: serve GIF as og:video (Discord renders it animated)
      ...(userAgent.toLowerCase().includes("discord")
        ? {
            "og:video": `${BASE_URL}/unfurls/odozi/main.gif`,
            "og:video:type": "image/gif",
            "og:video:width": "1200",
            "og:video:height": "630",
            "og:video:secure_url": `${BASE_URL}/unfurls/odozi/main.gif`,
          }
        : {}),

      // LinkedIn: custom linkedin-specific meta tags
      "linkedin:image": `${BASE_URL}/unfurls/odozi/main.gif`,
      "linkedin:image:type": "image/gif",
      "linkedin:image:width": "1200",
      "linkedin:image:height": "630",
    },
  };
}

// Static JSON-LD structured data - all values are hardcoded string literals, no user input
const jsonLd = {
  "@context": "https://schema.org",
  "@type": "MobileApplication",
  name: "Odozi",
  alternateName: "Odozi: Mood Journal",
  applicationCategory: "HealthApplication",
  applicationSubCategory: "Lifestyle",
  operatingSystem: "iOS 17",
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
  },
  description: DESCRIPTION,
  url: BASE_URL,
  downloadUrl: `https://apps.apple.com/us/app/odozi/id${APP_STORE_ID}`,
  installUrl: `https://apps.apple.com/us/app/odozi/id${APP_STORE_ID}`,
  author: {
    "@type": "Person",
    name: "John Larkin",
  },
  keywords:
    "mood journal, gratitude journal, daily reflection, mood tracker, sleep tracker, screen time tracker, private journal, mindfulness, wellbeing, mental health, habit tracker, journal prompts",
  featureList: [
    "Two-minute daily check-ins",
    "Mood and feeling tracking",
    "Gratitude journaling",
    "Sleep, steps, and screen time correlations",
    "Mood-coded journey map",
    "Word cloud of your entries",
    "Year-in-review recap",
    "Local-first storage with optional CloudKit sync",
  ],
  screenshot: [
    `${BASE_URL}/screenshots/today-tab.png`,
    `${BASE_URL}/screenshots/guided-journaling.png`,
    `${BASE_URL}/screenshots/insights-dashboard.png`,
    `${BASE_URL}/screenshots/map-visualization.png`,
    `${BASE_URL}/screenshots/word-cloud.png`,
    `${BASE_URL}/screenshots/year-in-review.png`,
  ],
  inLanguage: "en",
  isAccessibleForFree: true,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <head>
        {/* Safe: jsonLd is a compile-time constant with no dynamic/user input */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body
        className={`${geistSans.variable} ${geistMono.variable} ${spaceGrotesk.variable} font-sans antialiased bg-deep-space text-star-white`}
      >
        <PostHogProvider>
          <MotionConfigProvider>
            <Header />
            <main>{children}</main>
            <Footer />
          </MotionConfigProvider>
        </PostHogProvider>
      </body>
    </html>
  );
}
