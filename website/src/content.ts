export const APP_STORE_URL =
  "https://apps.apple.com/us/app/odozi/id6760240423";
export const GITHUB_URL = "https://github.com/johnlarkin1/odyssey";

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------
export const hero = {
  title: "Odozi",
  tagline: "a journal for your journey",
  subtitle:
    "An open-source project to help you be a bit more cognizant of your days. Available on MacOS, iOS, watchOS. It's your data, and it doesn't even have to leave your device",
  cta: "App Store",
};

// ---------------------------------------------------------------------------
// Why Download
// ---------------------------------------------------------------------------
export const whyDownload = {
  heading: "What is this and why should I download it?",
  headingAccent: "Why should I care?",
  // Supports inline markdown: [text](url) for links, *text* for italics
  paragraphs: [
    `It's one of probably [~1k journaling apps sitting on the App Store](https://chatgpt.com/share/69c133db-867c-800a-a183-156d876c77e3). And as for why you should care? Honestly? You really don't need to! it's 2026. we're ["nearing the exponential" per Dario](https://www.youtube.com/watch?v=n1E9IZfvGMA). [SaaSpocalypse](https://deathbyclawd.com/) and all that. I'm barrelling towards [the permanent underclass](https://www.newyorker.com/culture/infinite-scroll/will-ai-trap-you-in-the-permanent-underclass). [Fork this and build it yourself if you wish](https://github.com/johnlarkin1/odyssey). This is something I built for [me](https://johnlarkin1.github.io/). I like it because it's metrics that **I** care about. I also think it's kinda beautiful, and I like the background location snapshot (I'll get into security below) and integration with your camera roll. It's got Apple Health integrations, some basic metrics that I think are important for tracking my internal attitude and happiness, and things that I want to be reminded and cognizant about.`,
    `If you don't like it, that's great! Feel free to leave a [Github Issue](https://github.com/johnlarkin1/odyssey/issues) with a feature request or any bugs, or even better, clone the repo, start ripping some [Claude Code](https://docs.anthropic.com/en/docs/claude-code) / [Codex](https://openai.com/index/codex/) / [OpenCode](https://opencode.ai) / [Gemini CLI](https://github.com/google-gemini/gemini-cli) / [Cursor](https://www.cursor.com/) / &lt;insert-generic-agentic-cli-tool&gt; (although seriously where's my kickback anthropic) and modify it as you wish.`,
    `You'll still have to fight the fight with Apple and provisioning (man that [Family Controls distribution entitlement](https://developer.apple.com/documentation/xcode/configuring-family-controls) is a pita and they are slow), but who cares honestly — I had this just running locally on my phone as a dev build for a month before I had people asking about distribution.`,
  ],
};

// ---------------------------------------------------------------------------
// How It Works
// ---------------------------------------------------------------------------
export const howItWorks = {
  heading: "How it",
  headingAccent: "works.",
  subtitle:
    "Super simple click through. No account required! Your data either local on your device, or encrypted and stored in the cloud.",
  steps: [
    {
      number: "1",
      title: "Open the app",
      description: "Tap today's check-in.",
      color: "text-accent-amber",
      bg: "bg-accent-amber/10",
      border: "border-accent-amber/30",
    },
    {
      number: "2",
      title: "Answer a few prompts",
      description: "8 (or more) quick questions. Feel free to skip them.",
      color: "text-cosmic-purple",
      bg: "bg-cosmic-purple/10",
      border: "border-cosmic-purple/30",
    },
    {
      number: "3",
      title: "On-device analysis",
      description:
        "Years ago, [I noticed after self collecting some data](https://johnlarkin1.github.io/2021/year-in-review/#:~:text=I%20saw%20a%20very%20slightly%20%28albeit%20not%20statistically%20significant%29%20decrease%20in%20my%20happiness%20on%20days%20where%20my%20screen%20time%20and%20phone%20pickups%20were%20up), an inverse correlation between my screen time and my mood (shocker). This app is all about surfacing those invsible trends with data you provide.",
      color: "text-accent-teal",
      bg: "bg-accent-teal/10",
      border: "border-accent-teal/30",
    },
  ],
};

// ---------------------------------------------------------------------------
// What You Track (Guided Journaling + Passive Capture combined)
// ---------------------------------------------------------------------------
export const whatYouTrack = {
  heading: "What you",
  headingAccent: "track.",
  subtitle:
    "I mean, TLDR is it's really whatever you want to track. The automatic tracking elements can be turned off shortly as well.",
  prompts: [
    { title: "Mood", description: "How are you feeling right now" },
    { title: "Feeling", description: "Pick a word and color for your emotion" },
    { title: "Sleep", description: "How'd you sleep last night" },
    { title: "Gratitude", description: "Something you're grateful for" },
    { title: "Win", description: "A small or big win today" },
    { title: "Tension", description: "What's weighing on you" },
    { title: "Journal", description: "Free-write whatever's on your mind" },
    { title: "Drinks", description: "Track alcohol consumption" },
  ],
  backgroundLabel: "Captured automatically",
  backgroundItems: [
    {
      title: "Location",
      description: "One GPS snapshot per day, reverse-geocoded to city/state",
    },
    {
      title: "Health",
      description: "Steps, distance, and sleep from HealthKit",
    },
    {
      title: "Screen Time",
      description: "Total screen time and pickups via DeviceActivity",
    },
  ],
};

// ---------------------------------------------------------------------------
// What You Get Back (Insights + Year in Review combined)
// ---------------------------------------------------------------------------
export const whatYouGetBack = {
  heading: "What you",
  headingAccent: "get back.",
  subtitle:
    "Odozi connects the dots between your mood, habits, and daily context.",
  items: [
    {
      title: "Mood Trends",
      description: "See how your mood shifts over weeks and months",
    },
    {
      title: "Word Cloud",
      description: "Your most-used journal words, visualized",
    },
    {
      title: "Streaks",
      description: "Track your journaling consistency",
    },
    {
      title: "Journey Map",
      description: "Mood-coded pins on a map of where you've been",
    },
    {
      title: "Correlations",
      description: "Connections between sleep, steps, screen time, and mood",
    },
    {
      title: "Year in Review",
      description:
        "Spotify Wrapped-style recap - moods, streaks, top feelings, turned into shareable cards",
    },
  ],
};

// ---------------------------------------------------------------------------
// Screenshots (shared by HeroSection and FeatureGrid carousel)
// ---------------------------------------------------------------------------
export const screenshots = [
  {
    src: "/screenshots/today-tab.png",
    label: "Today",
    alt: "Today tab with daily greeting and health stats",
  },
  {
    src: "/screenshots/guided-journaling.png",
    label: "Journaling",
    alt: "Guided journaling flow with mood check-in",
  },
  {
    src: "/screenshots/insights-dashboard.png",
    label: "Insights",
    alt: "Insights dashboard with mood trends and streaks",
  },
  {
    src: "/screenshots/map-visualization.png",
    label: "Map",
    alt: "Journey map with color-coded mood pins",
  },
  {
    src: "/screenshots/word-cloud.png",
    label: "Word Cloud",
    alt: "Word cloud of most-used journal words",
  },
  {
    src: "/screenshots/year-in-review.png",
    label: "Year in Review",
    alt: "Spotify Wrapped-style year in review",
  },
];

// ---------------------------------------------------------------------------
// Privacy / Trust
// ---------------------------------------------------------------------------
export const privacy = {
  heading: "Your data",
  headingAccent: "stays yours.",
  subtitle:
    "I cannot emphasize this enough. I couldn't check this data if I tried.",
  cards: [
    {
      title: "On-Device",
      desc: "All data stored locally by default. Only goes over the network if you make an account for redundancy and sync",
    },
    {
      title: "CloudKit Sync",
      desc: "Optional sync powered by Apple's CloudKit. Basically, this app will have a dedicated CloudKit container, and each user gets their own dedicated database. Don't believe me? Well, [RTFM](https://developer.apple.com/library/archive/documentation/General/Conceptual/iCloudDesignGuide/DesigningforCloudKit/DesigningforCloudKit.html) (also [here](https://developer.apple.com/documentation/CloudKit/CKContainer/privateCloudDatabase)) or take it up with Apple.",
    },
    {
      title: "No Tracking",
      desc: "Zero analytics (minus... this marketing website so I can see activations), zero ads, zero data sharing",
    },
  ],
};

// ---------------------------------------------------------------------------
// Final CTA
// ---------------------------------------------------------------------------
export const finalCTA = {
  heading: "Give it",
  headingAccent: "a shot.",
  subtitle: "Free. No account required. No strings.",
  bullets: ["No account required", "No ads, ever", "No subscription"],
  cta: "Download on the App Store",
};

// ---------------------------------------------------------------------------
// FAQ
// ---------------------------------------------------------------------------
export const faqs = [
  {
    question: "Is Odozi free?",
    answer:
      "Yep. Completely free. No subscriptions, no in-app purchases, no ads.",
  },
  {
    question: "Where is my data stored?",
    answer:
      "On your device. If you turn on cloud backup, it's end-to-end encrypted (AES-256-GCM) — only you can read it.",
  },
  {
    question: "How long does the daily check-in take?",
    answer:
      "About 1-2 minutes. There are 8 prompts and every single one is skippable.",
  },
  {
    question: "Do I need an account?",
    answer:
      "Nope. Odozi works fully without one. You only need an account if you want cloud backup and it'll use your iCloud account to sync your data.",
  },
  {
    question: "Is there an Android version?",
    answer: "Not yet. iOS only for now (iPhone, iOS 17+).",
  },
  {
    question: "Can I export my data?",
    answer: "Yes. CSV export from the Profile tab anytime. Your data is yours.",
  },
];

// ---------------------------------------------------------------------------
// Support
// ---------------------------------------------------------------------------
export const support = {
  heading: "Support",
  intro: "Need help with Odozi? I usually respond within a week.",
  contact: {
    email: "john@odozi.app",
    emailNote: "For privacy questions or anything you'd rather keep private.",
    githubIssuesUrl: `${GITHUB_URL}/issues`,
    githubNote: "For bugs and feature requests. Please use those labels!",
  },
  permissions: [
    {
      title: "Location",
      why: "One GPS snapshot per day, stored on-device, for your journey map.",
    },
    {
      title: "Apple Health",
      why: "Reads steps, walking distance, and sleep from HealthKit.",
    },
    {
      title: "Screen Time",
      why: "Daily totals and pickups via Apple's DeviceActivity framework.",
    },
    {
      title: "Notifications",
      why: "Optional daily nudge to open the app. Off by default.",
    },
  ],
  yourData: [
    {
      title: "Export",
      body: "Profile tab, Export CSV. Your whole journal, any time.",
    },
    {
      title: "Sync",
      body: "CloudKit sync is opt-in and off by default. When on, your data syncs to your private iCloud container.",
    },
    {
      title: "Delete",
      body: "Uninstalling removes everything on-device. If CloudKit sync was on, also delete the Odozi container from Settings, [your name], iCloud, Manage Account Storage, Odozi.",
    },
  ],
  platform: "iPhone only, iOS 17 or later.",
  knownIssues:
    "Nothing reported right now. Latest status lives on GitHub Issues.",
  troubleshooting: [
    {
      question: "My Screen Time numbers look wrong or are zero.",
      answer:
        "Screen Time requires the Family Controls permission and a physical device. Go to Profile, Permissions and confirm it's granted. If it's already on, toggle it off and back on.",
    },
    {
      question: "My streak dropped even though I journaled.",
      answer:
        "Streaks use your device's local timezone at midnight, so crossing timezones can cause a skip... Once again, because we're using CloudKit, I cannot even access your data. You can fix it yourself: open the Journal tab, tap the missing day, and fill it in. Past entries are editable. If there is a bug please, file a GitHub Issue.",
    },
    {
      question: "I turned on CloudKit sync but nothing's syncing.",
      answer:
        "CloudKit sync needs an active iCloud account and an internet connection. The first run can take a few minutes. If it's still stuck after ten, toggle sync off and back on.",
    },
    {
      question: "Can I use Odozi on iPad or Mac?",
      answer: "iPhone only for now.",
    },
    {
      question: "How do I delete my data?",
      answer:
        "Uninstall the app to wipe everything on-device. If CloudKit sync was on, also delete the Odozi container from Settings > [your name] > iCloud > Manage Account Storage > Odozi.",
    },
    {
      question: "I found a bug. How do I report it?",
      answer:
        "GitHub Issues is best. Include your iOS version and a short repro. Email works too.",
    },
  ],
};

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------
export const footer = {
  tagline: "a journal for your journey",
  madeIn: "Made in NYC.",
};
