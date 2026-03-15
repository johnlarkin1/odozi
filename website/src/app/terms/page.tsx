import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Service — Odyssey",
  description: "Terms of service for the Odyssey journaling app.",
  alternates: {
    canonical: "/terms",
  },
};

export default function TermsOfService() {
  return (
    <article className="prose prose-invert mx-auto max-w-3xl px-6 py-24">
      <h1>Terms of Service</h1>
      <p className="lead">
        Effective date: March 1, 2026
      </p>

      <hr />

      <h2>1. Acceptance of Terms</h2>
      <p>
        By downloading, installing, or using Odyssey (&quot;the app&quot;), you agree to be bound
        by these Terms of Service. If you do not agree, do not use the app.
      </p>

      <h2>2. Description of Service</h2>
      <p>
        Odyssey is a personal journaling and wellness tracking app for iOS. It provides
        guided daily prompts, passive background data capture (location, health metrics,
        screen time), visualizations, and a year-in-review feature. The app is designed
        for personal, non-commercial use.
      </p>

      <h2>3. User Accounts</h2>
      <p>
        Account creation is optional. If you choose to create an account using Sign in
        with Apple or Google (via Clerk), you are responsible for maintaining the security
        of your account credentials. You agree to notify us immediately of any unauthorized
        use of your account.
      </p>

      <h2>4. Acceptable Use</h2>
      <p>You agree to use Odyssey for personal, non-commercial purposes only. You may not:</p>
      <ul>
        <li>Reverse engineer, decompile, or disassemble the app</li>
        <li>Use the app to collect data about other individuals without their consent</li>
        <li>Attempt to gain unauthorized access to our systems or services</li>
        <li>Use the app in any way that violates applicable laws or regulations</li>
      </ul>

      <h2>5. Data and Privacy</h2>
      <p>
        Your use of the app is also governed by our{" "}
        <a href="/privacy">Privacy Policy</a>, which describes how we collect, use, and
        protect your data. You retain ownership of all content you create within the app,
        including journal entries, mood data, and photos.
      </p>

      <h2>6. Cloud Backup</h2>
      <p>
        If you enable optional cloud backup, your data is encrypted end-to-end on your
        device before transmission. We provide cloud backup on a best-effort basis and
        are not liable for data loss. If you lose your encryption keys, we cannot recover
        your backed-up data.
      </p>

      <h2>7. HealthKit</h2>
      <p>
        With your permission, Odyssey reads health data (steps, walking distance, sleep)
        from Apple HealthKit. This data is:
      </p>
      <ul>
        <li>Read-only — we never write to HealthKit</li>
        <li>Never used for advertising or marketing purposes</li>
        <li>Never shared with third parties for advertising</li>
        <li>Revocable at any time via iOS Settings &gt; Health &gt; Data Access</li>
      </ul>

      <h2>8. Intellectual Property</h2>
      <p>
        The Odyssey app, its design, code, visual elements, and brand are proprietary
        and protected by intellectual property laws. You may not copy, modify, distribute,
        or create derivative works based on the app without our written permission.
      </p>

      <h2>9. Disclaimers</h2>
      <p>
        <strong>Odyssey is not a medical device or healthcare service.</strong> The app
        does not provide medical advice, diagnosis, or treatment. Mood tracking, health
        metrics, and insights are for personal reflection only and should not be used as
        a substitute for professional medical advice.
      </p>
      <p>
        The app is provided &quot;as is&quot; without warranties of any kind, express or implied,
        including but not limited to warranties of merchantability, fitness for a particular
        purpose, or non-infringement.
      </p>

      <h2>10. Limitation of Liability</h2>
      <p>
        To the maximum extent permitted by applicable law, the developers of Odyssey shall
        not be liable for any indirect, incidental, special, consequential, or punitive
        damages arising out of or related to your use of the app, including but not limited
        to loss of data, emotional distress, or interruption of service.
      </p>

      <h2>11. Termination</h2>
      <p>
        We may suspend or terminate your access to the app at any time for violation of
        these terms. You may stop using the app at any time. Upon termination, your local
        data remains on your device. Cloud data is deleted within 30 days of account deletion.
      </p>

      <h2>12. Governing Law</h2>
      <p>
        These terms are governed by the laws of the State of Illinois, United States,
        without regard to conflict of law provisions.
      </p>

      <h2>13. Contact</h2>
      <p>
        If you have questions about these terms, please contact us at{" "}
        <a href="mailto:john@johnjlarkin.com">john@johnjlarkin.com</a>.
      </p>
    </article>
  );
}
