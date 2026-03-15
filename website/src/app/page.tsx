import { HeroSection } from "@/components/HeroSection";
import { HowItWorks } from "@/components/HowItWorks";
import {
  GuidedJournalingSection,
  PassiveCaptureSection,
  InsightsSection,
  YearInReviewSection,
  ScreenshotCarousel,
} from "@/components/FeatureGrid";
import { PrivacySection, FinalCTASection } from "@/components/CTASection";
import { FAQSection } from "@/components/FAQSection";
import { WaveDivider } from "@/components/WaveDivider";

export default function Home() {
  return (
    <>
      <HeroSection />
      <HowItWorks />
      <WaveDivider />
      <GuidedJournalingSection />
      <PassiveCaptureSection />
      <WaveDivider />
      <InsightsSection />
      <YearInReviewSection />
      <ScreenshotCarousel />
      <WaveDivider />
      <PrivacySection />
      <FAQSection />
      <FinalCTASection />
    </>
  );
}
