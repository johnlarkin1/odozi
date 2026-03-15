import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Odyssey — Your Daily Journey Inward",
  description:
    "A guided journaling app for iOS that captures your world and reveals patterns in your wellbeing.",
  metadataBase: new URL("https://odozi.app"),
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: "Odyssey — Your Daily Journey Inward",
    description:
      "A guided journaling app for iOS that captures your world and reveals patterns in your wellbeing.",
    url: "https://odozi.app",
    siteName: "Odyssey",
    images: "/og-image.png",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Odyssey — Your Daily Journey Inward",
    description:
      "A guided journaling app for iOS that captures your world and reveals patterns in your wellbeing.",
    images: "/og-image.png",
  },
};

// Static JSON-LD structured data — all values are hardcoded string literals, no user input
const jsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Odyssey",
  applicationCategory: "HealthApplication",
  operatingSystem: "iOS 17+",
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
  },
  description:
    "A guided journaling app for iOS that captures your world — location, health, screen time — and reveals patterns in your wellbeing.",
  url: "https://odozi.app",
  downloadUrl: "https://apps.apple.com/app/odyssey-journal/id6743597741",
  author: {
    "@type": "Person",
    name: "John Larkin",
  },
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
        className={`${geistSans.variable} ${geistMono.variable} font-sans antialiased bg-deep-space text-star-white`}
      >
        <Header />
        <main>{children}</main>
        <Footer />
      </body>
    </html>
  );
}
