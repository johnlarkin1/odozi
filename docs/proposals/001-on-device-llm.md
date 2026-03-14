---
title: On-Device LLM Integration via Apple Foundation Models
status: draft
date: 2026-03-14
tags: [ai, ios26, foundation-models, journaling, insights]
---

# 001 — On-Device LLM Integration

## Summary

Integrate Apple's Foundation Models framework to add AI-powered journaling features — personalized follow-up prompts, entry summaries, weekly digests, and mood pattern insights — all running entirely on-device with zero data leaving the phone.

## Motivation

Odyssey captures rich daily data (mood, journal text, gratitude, wins, tensions, sleep, location, screen time) but currently relies on the user to draw their own connections. An on-device LLM can surface patterns and generate personalized reflections that make the journaling experience significantly more valuable — without compromising the privacy-first design that's core to the app.

Key user benefits:
- **Lower friction** — AI-generated follow-up questions keep the reflection going without the user staring at a blank page
- **Pattern recognition** — "You tend to feel better on days you mention exercise" is the kind of insight users can't easily see themselves
- **Richer entries** — Expanding on brief gratitude notes or tensions turns bullet points into meaningful reflections
- **Engagement** — Weekly digests and "on this day" reflections give users reasons to return

## Technical Approach

### Framework Overview

Apple's **Foundation Models framework** (iOS 26+, WWDC 2025) provides direct access to the on-device LLM powering Apple Intelligence. Key properties:

- **Completely on-device** — no network calls, no API keys, no data leaves the phone
- **Free** — no per-token costs, no rate limits
- **Private by design** — ideal for sensitive wellness data
- **Typed output** — `@Generable` macro produces Swift structs, not just strings

### Core API Patterns

#### Plain text generation

```swift
import FoundationModels

let session = LanguageModelSession(instructions: """
    You are a compassionate journaling coach for a wellness app called Odyssey.
    You help users reflect deeply on their day without being preachy or clinical.
    Keep responses warm, concise, and actionable.
    """)

let response = try await session.respond(
    to: "Help me reflect on feeling overwhelmed but finishing my presentation"
)
// response.content -> free-form encouragement text
```

#### Structured output with @Generable

The standout feature — the model generates **typed Swift structs**, not just strings:

```swift
import FoundationModels

@Generable
struct JournalInsight {
    @Guide(description: "A personalized follow-up question based on the entry")
    let followUpQuestion: String

    @Guide(description: "The primary emotion detected, as a single word")
    let detectedEmotion: String

    @Guide(description: "A brief encouraging reflection in 1-2 sentences")
    let encouragement: String

    @Guide(description: "One actionable suggestion for tomorrow")
    let suggestion: String
}

let session = LanguageModelSession()
let response = try await session.respond(
    to: "Today I felt overwhelmed by deadlines but managed to finish my presentation",
    generating: JournalInsight.self
)

let insight: JournalInsight = response.content
// insight.followUpQuestion -> "What helped you push through to finish the presentation?"
// insight.detectedEmotion -> "resilient"
// insight.encouragement -> "You showed real strength today by finishing despite the pressure."
// insight.suggestion -> "Tomorrow, try blocking 30 minutes of focus time before your first meeting."
```

#### Tool calling (querying past entries)

The model can call back into app code to access SwiftData:

```swift
import FoundationModels

struct SearchPastEntriesTool: Tool {
    let modelContext: ModelContext

    func execute(query: String) async throws -> String {
        let descriptor = FetchDescriptor<DailyEntry>(
            predicate: #Predicate { $0.journalEntry?.contains(query) == true },
            sortBy: [SortDescriptor(\.entryDate, order: .reverse)]
        )
        let entries = try modelContext.fetch(descriptor)
        let summaries = entries.prefix(5).map { entry in
            "\(entry.entryDate.formatted(.dateTime.month().day())): \(entry.journalEntry ?? "No entry")"
        }
        return summaries.joined(separator: "\n")
    }
}

let session = LanguageModelSession(
    tools: [SearchPastEntriesTool(modelContext: context)],
    instructions: """
        You help users reflect by connecting today's entry to past patterns.
        Use the search tool to find relevant past entries when the user mentions
        recurring themes like work stress, exercise, or relationships.
        """
)
```

#### Streaming for real-time UI

```swift
let stream = session.streamResponse(to: prompt)
for try await partial in stream {
    // Update UI progressively
    self.displayText = partial.content
}
```

#### Multi-turn conversations

Reuse the same `LanguageModelSession` instance to maintain context:

```swift
let session = LanguageModelSession(instructions: "You are a journaling coach.")
let r1 = try await session.respond(to: "I had a tough day at work")
let r2 = try await session.respond(to: "Actually, one good thing happened...")
// r2 has full context of r1
```

## Integration Points

### 1. Post-Flow Insight (highest impact, lowest risk)

**Where:** After the 8-step guided prompt flow completes in `GuidedPromptFlowView`
**What:** Generate a `JournalInsight` from the user's combined responses
**How:** New `JournalInsightService` takes `PromptResponses`, builds a prompt, returns structured insight
**Files touched:**
- New: `Odyssey/Services/JournalInsightService.swift`
- Modified: `Odyssey/Views/GuidedPrompts/CompletionCardView.swift` (display insight)
- Modified: `Odyssey/ViewModels/GuidedPromptViewModel.swift` (trigger generation)

### 2. Entry Summaries for Journal List

**Where:** `JournalListView` — each row currently shows date + mood
**What:** Auto-generate a 1-sentence summary of each entry
**How:** Generate on save, store as `aiSummary: String?` on `DailyEntry`
**Files touched:**
- Modified: `Odyssey/Models/DailyEntry.swift` (add `aiSummary` field)
- Modified: `Odyssey/Views/Journal/` (display summary in list rows)
- New: `Odyssey/Services/EntrySummaryService.swift`

### 3. Weekly Digest

**Where:** New card on the Insights tab, or a notification-driven view
**What:** Summarize the past week's entries into themes, mood trajectory, and encouragement
**How:** Fetch week's entries, build a composite prompt, generate `WeeklyDigest` struct
**Files touched:**
- New: `Odyssey/Views/Insights/WeeklyDigestCard.swift`
- New: `Odyssey/Services/WeeklyDigestService.swift`
- Modified: `Odyssey/Views/Insights/InsightsDashboardView.swift` (add card)

### 4. Mood Pattern Insights

**Where:** Insights tab — new "AI Insights" card
**What:** Cross-reference mood scores with journal text, sleep, steps, screen time to surface correlations
**How:** Tool calling to query entries by mood range + structured output for insight cards
**Files touched:**
- New: `Odyssey/Services/PatternInsightService.swift`
- New: `Odyssey/Views/Insights/AIInsightsCard.swift`

### 5. "On This Day" Reflections

**Where:** Today tab, shown when the user has entries from the same date in prior years
**What:** Pull the past entry and generate a reflection connecting then to now
**How:** Tool calling to fetch historical entry + text generation
**Files touched:**
- New: `Odyssey/Views/Today/OnThisDayCard.swift`
- Modified: `Odyssey/Views/Today/TodayView.swift`

### 6. Gratitude/Tension Expansion

**Where:** During the guided prompt flow (Gratitude and Tension steps)
**What:** After the user types a brief note, offer an AI-generated deeper reflection prompt
**How:** Inline generation with streaming, shown as an optional "Reflect deeper?" button
**Files touched:**
- Modified: `Odyssey/Views/GuidedPrompts/Cards/GratitudeCardView.swift`
- Modified: `Odyssey/Views/GuidedPrompts/Cards/TensionCardView.swift`

## Trade-offs & Constraints

### Device Requirements

- **iOS 26+** required (ships fall 2026)
- **Apple Intelligence-capable hardware only**: iPhone 15 Pro+, M-series iPads/Macs
- Odyssey currently targets iOS 17+ — these features must be gated behind availability checks

### Availability Gating Strategy

```swift
import FoundationModels

var isFoundationModelsAvailable: Bool {
    if #available(iOS 26, *) {
        return SystemLanguageModel.default.isAvailable
    }
    return false
}
```

The app should:
- **Never require** Foundation Models for core functionality
- Show AI features only when available, with graceful degradation
- Not mention "AI" in contexts where the device can't support it (avoid frustrating users on older hardware)

### Performance Considerations

- On-device inference is slower than cloud APIs — expect 1-3 seconds for short generations
- Use **streaming** for anything user-facing to avoid perceived lag
- Generate summaries/digests **asynchronously** (on save or in background), not on-demand in scroll views
- Cache generated content (store on `DailyEntry` model) to avoid regenerating

### Privacy

This is a major **advantage** — all processing stays on-device. No journal text, mood data, or health metrics ever leave the phone. This aligns perfectly with Odyssey's privacy-first positioning and should be highlighted in marketing.

### Model Limitations

The on-device model is capable but not as powerful as cloud LLMs. It excels at:
- Summarization, text understanding, entity extraction
- Creative/empathetic writing (coaching prompts, reflections)
- Structured output generation

It may struggle with:
- Complex multi-step reasoning
- Mathematical analysis of mood trends (better to compute these programmatically and feed results to the model for narration)
- Very long context windows (keep prompts focused)

**Mitigation:** Do quantitative analysis in Swift code (trend calculations, correlations — which Odyssey already does via `TrendCalculator` and `CorrelationService`), then pass computed results to the model for natural language narration.

## Open Questions

1. **Phased rollout or all-at-once?** Recommend starting with Post-Flow Insight (#1) as a standalone feature, then expanding.
2. **User opt-in?** Should AI features be on by default or require explicit opt-in in Settings? Given the sensitivity of journal data, opt-in may build more trust — even though processing is on-device.
3. **Caching strategy:** Store AI-generated content on `DailyEntry` model? Separate model? UserDefaults? SwiftData fields are simplest but add schema migration.
4. **Regeneration:** Should users be able to tap "try again" to get a different insight? Multi-turn sessions make this easy but costs inference time.
5. **Branding:** How to communicate "AI" features without triggering user skepticism? "Powered by Apple Intelligence" carries trust. Avoid generic "AI" branding.

## Next Steps

1. **Prototype `JournalInsightService`** — Standalone service with `@Generable` struct, hardcoded prompt, tested with sample entries
2. **Add availability gating utility** — `FoundationModelsAvailability` helper that other features can check
3. **Integrate into CompletionCardView** — Show generated insight after guided flow completion
4. **Design the UI** — Insight card design that fits the existing dark-mode aesthetic
5. **Add a Settings toggle** — "AI Reflections" on/off in Profile tab
6. **Expand to entry summaries** — Second integration point, requires `DailyEntry` schema change
