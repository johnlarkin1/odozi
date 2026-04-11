import type { MetadataRoute } from "next";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://odozi.app",
      lastModified: "2026-03-15",
      changeFrequency: "weekly",
      priority: 1,
    },
    {
      url: "https://odozi.app/support",
      lastModified: "2026-04-11",
      changeFrequency: "monthly",
      priority: 0.7,
    },
    {
      url: "https://odozi.app/privacy",
      lastModified: "2026-03-15",
      changeFrequency: "monthly",
      priority: 0.5,
    },
    {
      url: "https://odozi.app/terms",
      lastModified: "2026-03-15",
      changeFrequency: "monthly",
      priority: 0.5,
    },
  ];
}
