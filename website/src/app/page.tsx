import { HeroSection } from "@/components/HeroSection";
import { WhyDownloadSection } from "@/components/WhyDownloadSection";
import {
  WhatYouTrackSection,
  WhatYouGetBackSection,
} from "@/components/FeatureGrid";
import { PrivacySection, FinalCTASection } from "@/components/CTASection";
import { FAQSection } from "@/components/FAQSection";
import { WaveDivider } from "@/components/WaveDivider";

export default function Home() {
  return (
    <>
      <HeroSection />
      <WhyDownloadSection />
      <WaveDivider />
      <WhatYouTrackSection />
      <WaveDivider />
      <WhatYouGetBackSection />
      <PrivacySection />
      <FAQSection />
      <FinalCTASection />
    </>
  );
}
