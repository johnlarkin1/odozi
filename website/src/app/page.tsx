import { HeroSection } from "@/components/HeroSection";
import { HowItWorks } from "@/components/HowItWorks";
import {
  GuidedJournalingSection,
  PassiveCaptureSection,
  InsightsSection,
  YearInReviewSection,
} from "@/components/FeatureGrid";
import { PrivacySection, FinalCTASection } from "@/components/CTASection";
import { FAQSection } from "@/components/FAQSection";

export default function Home() {
  return (
    <>
      <HeroSection />
      <HowItWorks />
      <GuidedJournalingSection />
      <PassiveCaptureSection />
      <InsightsSection />
      <YearInReviewSection />
      <PrivacySection />
      <FAQSection />
      <FinalCTASection />
    </>
  );
}
