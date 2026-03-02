import { HeroSection } from "@/components/HeroSection";
import {
  GuidedJournalingSection,
  PassiveCaptureSection,
  InsightsSection,
  YearInReviewSection,
} from "@/components/FeatureGrid";
import { PrivacySection, FinalCTASection } from "@/components/CTASection";

export default function Home() {
  return (
    <>
      <HeroSection />
      <GuidedJournalingSection />
      <PassiveCaptureSection />
      <InsightsSection />
      <YearInReviewSection />
      <PrivacySection />
      <FinalCTASection />
    </>
  );
}
