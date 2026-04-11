import type { Metadata } from "next";
import Link from "next/link";
import { FAQSection } from "@/components/FAQSection";
import { support } from "@/content";

export const metadata: Metadata = {
  title: "Support - Odyssey",
  description:
    "Get help with Odyssey — contact, troubleshooting, permissions, and data export.",
  alternates: {
    canonical: "/support",
  },
};

export default function Support() {
  return (
    <>
      <article className="prose prose-invert mx-auto max-w-3xl px-6 py-24">
        <h1>{support.heading}</h1>
        <p className="lead">{support.intro}</p>

        <hr />

        <h2>Get in touch</h2>
        <p>
          <strong>Email:</strong>{" "}
          <a href={`mailto:${support.contact.email}`}>{support.contact.email}</a>
          {" — "}
          {support.contact.emailNote}
        </p>
        <p>
          <strong>GitHub Issues:</strong>{" "}
          <a
            href={support.contact.githubIssuesUrl}
            target="_blank"
            rel="noopener noreferrer"
          >
            {support.contact.githubIssuesUrl}
          </a>
          {" — "}
          {support.contact.githubNote}
        </p>

        <h2>Permissions Odyssey asks for</h2>
        <p>
          Odyssey is useful in direct proportion to what it can see. Every permission
          is optional — if you say no, the app still works, you just get less out of it.
        </p>
        <ul>
          {support.permissions.map((p) => (
            <li key={p.title}>
              <strong>{p.title}</strong> — {p.why}
            </li>
          ))}
        </ul>

        <h2>Your data</h2>
        <ul>
          {support.yourData.map((d) => (
            <li key={d.title}>
              <strong>{d.title}</strong> — {d.body}
            </li>
          ))}
        </ul>
        <p>
          For the full details, see the{" "}
          <Link href="/privacy">Privacy Policy</Link>.
        </p>

        <h2>Platform requirements</h2>
        <p>{support.platform}</p>

        <h2>Known issues</h2>
        <p>{support.knownIssues}</p>

        <hr />

        <p>
          Still stuck? Email{" "}
          <a href={`mailto:${support.contact.email}`}>{support.contact.email}</a>
          {" "}and I&apos;ll help you sort it out.
        </p>
      </article>

      <FAQSection
        items={support.troubleshooting}
        id="support-faq"
        heading="Troubleshooting"
        headingAccent="questions."
      />
    </>
  );
}
