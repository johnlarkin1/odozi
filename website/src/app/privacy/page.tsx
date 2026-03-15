import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy — Odyssey",
  description: "How Odyssey handles your data. Local-first, end-to-end encrypted, no tracking.",
  alternates: {
    canonical: "/privacy",
  },
};

export default function PrivacyPolicy() {
  return (
    <article className="prose prose-invert mx-auto max-w-3xl px-6 py-24">
      <h1>Privacy Policy</h1>
      <p className="lead">
        Effective date: March 1, 2026
      </p>
      <p>
        Odyssey (&quot;we,&quot; &quot;our,&quot; or &quot;the app&quot;) is a personal journaling and
        wellness tracking app for iOS. We are committed to protecting your privacy.
        This policy explains what data we collect, how we use it, and your rights.
      </p>

      <hr />

      <h2>1. Data You Provide</h2>
      <p>
        When you use the guided journaling flow, you may provide the following data:
      </p>
      <ul>
        <li><strong>Mood rating</strong> — a numeric value representing your daily mood</li>
        <li><strong>Feeling word &amp; color</strong> — a single word describing your emotion and an associated color</li>
        <li><strong>Sleep quality</strong> — a rating of how well you slept</li>
        <li><strong>Gratitude entry</strong> — a free-text note on what you&apos;re grateful for</li>
        <li><strong>Daily win</strong> — a free-text note on a positive event or accomplishment</li>
        <li><strong>Tension entry</strong> — a free-text note on what&apos;s causing stress</li>
        <li><strong>Journal entry</strong> — a free-form text entry</li>
        <li><strong>Drinks</strong> — a numeric count of alcoholic beverages consumed</li>
        <li><strong>Photos</strong> — optional images you attach to entries</li>
      </ul>
      <p>All fields are optional. Every step in the guided flow is skippable.</p>

      <h2>2. Data Collected Automatically</h2>
      <p>
        With your explicit permission, Odyssey collects the following data in the background:
      </p>
      <ul>
        <li>
          <strong>Location</strong> — a single-shot GPS request per daily snapshot, reverse-geocoded
          to city, state, and country. We do not continuously track your location.
        </li>
        <li>
          <strong>HealthKit data</strong> — steps, walking distance, and sleep analysis. This data is
          read from Apple HealthKit with your authorization and is never used for advertising or
          marketing purposes, in compliance with Apple&apos;s HealthKit guidelines.
        </li>
        <li>
          <strong>Screen Time</strong> — total screen time in seconds and pickup count, collected via
          Apple&apos;s DeviceActivity framework.
        </li>
      </ul>

      <h2>3. Account Data (Optional)</h2>
      <p>
        You may optionally create an account using Sign in with Apple or Google (via Clerk).
        If you do, we store your name and email address for authentication and cloud backup
        purposes only.
      </p>

      <h2>4. How We Use Your Data</h2>
      <p>Your data is used exclusively to:</p>
      <ul>
        <li>Display your journal entries and daily snapshots</li>
        <li>Generate insights, visualizations, and trend analysis within the app</li>
        <li>Power the year-in-review feature with your personal statistics</li>
      </ul>
      <p>
        We do <strong>not</strong> use your data for advertising, analytics, or marketing.
        HealthKit data is never used for advertising or transferred to third parties for
        advertising purposes.
      </p>

      <h2>5. Data Storage</h2>
      <p>
        Odyssey is <strong>local-first</strong>. All journal data is stored on your device using
        Apple&apos;s SwiftData framework.
      </p>
      <p>
        If you enable optional cloud backup, your data is encrypted end-to-end using
        AES-256-GCM with field-level encryption before leaving your device. We cannot
        read your journal entries, even with access to the server.
      </p>

      <h2>6. Data Sharing</h2>
      <p>
        We do not sell, rent, or share your personal data with third parties. The only
        external services we use are:
      </p>
      <ul>
        <li><strong>Clerk</strong> — for authentication (only if you create an account)</li>
        <li><strong>Database hosting</strong> — for encrypted cloud backup storage (only if you enable backup)</li>
      </ul>

      <h2>7. Data Retention &amp; Deletion</h2>
      <ul>
        <li>Local data persists until you delete the app or remove entries manually.</li>
        <li>We prompt a cleanup for entries older than one year (optional).</li>
        <li>You can export all data to CSV at any time from the Profile tab.</li>
        <li>
          Account deletion removes all cloud-stored data within 30 days. Local data
          remains on your device until you delete it.
        </li>
      </ul>

      <h2>8. Your Rights</h2>
      <p>You have the right to:</p>
      <ul>
        <li><strong>Access</strong> — view and export all your data via the app</li>
        <li><strong>Delete</strong> — delete individual entries or your entire account</li>
        <li><strong>Portability</strong> — export your data to CSV</li>
        <li>
          <strong>Withdraw consent</strong> — revoke location, HealthKit, or Screen Time
          permissions at any time via iOS Settings
        </li>
      </ul>

      <h2>9. Children&apos;s Privacy</h2>
      <p>
        Odyssey is not directed at children under the age of 13. We do not knowingly collect
        personal information from children under 13. If we learn that we have collected data
        from a child under 13, we will delete it promptly.
      </p>

      <h2>10. Changes to This Policy</h2>
      <p>
        We may update this privacy policy from time to time. When we do, we will update the
        effective date at the top of this page. Continued use of the app after changes
        constitutes acceptance of the updated policy.
      </p>

      <h2>11. Contact</h2>
      <p>
        If you have questions about this privacy policy, please contact us at{" "}
        <a href="mailto:john@odozi.app">john@odozi.app</a>.
      </p>
    </article>
  );
}
