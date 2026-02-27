# Odyssey App Store Publication Plan

**Project Status:** Ready for publication with critical blockers identified
**Date:** February 26, 2026
**Current Version:** 1.0, Build 1

---

## Executive Summary

Odyssey is technically sound and architecturally ready for App Store submission. However, **5 critical blockers** must be resolved before submission. Additionally, **15 medium/low priority items** should be addressed for quality and compliance.

**Estimated Timeline:**
- FamilyControls entitlement approval: 1-30 days (start immediately)
- Code fixes: 2-3 days
- App Store metadata + screenshots: 2-3 days
- TestFlight validation: 1-2 days
- **Total: 1-6 weeks** (dependent on Apple's entitlement approval)

---

## 🔴 CRITICAL BLOCKERS (Must fix before submission)

### 1. Request FamilyControls Distribution Entitlement
**Status:** ❌ Not yet approved
**Risk:** Auto-rejection without approval
**Timeline:** 1-30+ days

The app uses `com.apple.developer.family-controls` across all 3 targets (main app, DeviceActivityMonitor extension, DeviceActivityReport extension). This is a **privileged entitlement** requiring explicit Apple approval.

**Action:**
1. Go to https://developer.apple.com/contact/request/family-controls-distribution
2. Submit one request per target/bundle ID:
   - `com.johnlarkin.Odyssey` (main app)
   - `com.johnlarkin.Odyssey.OdysseyDeviceActivityMonitor` (extension)
   - `com.johnlarkin.Odyssey.OdysseyDeviceActivityReport` (extension)
3. Explain use case: "Odyssey is a personal wellness journaling app that captures screen time context to enrich daily reflections. No parental control features."
4. Reference the official documentation: https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement
5. **DO THIS FIRST** — approval can take weeks

---

### 2. Create Privacy Manifest (PrivacyInfo.xcprivacy)
**Status:** ❌ Missing
**Risk:** Auto-rejection since May 1, 2024
**Timeline:** 1 hour

Apple requires a privacy manifest file declaring API usage for apps using required-reason APIs (UserDefaults, date/time, etc.).

**Action:**
1. Create `Odyssey/PrivacyInfo.xcprivacy` (XML plist format)
2. Declare API types:
   - `NSPrivacyAccessedAPICategoryUserDefaults` (reason: `CA92.1` — app group communication)
3. Set `NSPrivacyTracking = false` (Odyssey doesn't track users)
4. Add to main app target in Build Phases
5. Reference: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files

**Template:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key>
  <false/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>CA92.1</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
```

---

### 3. Fix Photo Library Permission
**Status:** ⚠️ Overly permissive
**Risk:** Medium — may trigger review questions
**Timeline:** 5 minutes

The app requests `.readWrite` permission for photos but never writes to the library.

**Action:**
- `PhotoLibraryService.swift:10` — Change `PHPhotoLibrary.requestAuthorization(for: .readWrite)` to `.readOnly`
- Requesting more permissions than needed triggers Apple scrutiny

---

### 4. Fix Location Authorization Flow
**Status:** ⚠️ Non-standard
**Risk:** Medium — may require revision during review
**Timeline:** 15 minutes

The app requests `requestAlwaysAuthorization()` immediately on launch. Apple expects apps to start with "When In Use" and upgrade only if needed.

**Action:**
- `OdysseyApp.swift:53` — Change to `requestWhenInUseAuthorization()` on launch
- Consider requesting "Always" upgrade at a contextual moment (e.g., when user enables background capture) with clear explanation
- This is a better user experience and looks less suspicious to reviewers

---

### 5. Fix Hardcoded Version String
**Status:** ❌ Mismatch
**Risk:** Low — cosmetic but looks sloppy
**Timeline:** 5 minutes

`ProfileView.swift:42` hardcodes `Text("2.0")` but the actual marketing version is `1.0`.

**Action:**
```swift
// ProfileView.swift:42
let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
Text(appVersion)
```

---

## 🟡 HIGH PRIORITY (Should fix before submission)

### 6. Replace all `print()` with `os.Logger`
**Status:** ⚠️ 11 print statements in production code
**Risk:** Code smell during review; hides errors from users
**Timeline:** 30 minutes

Files affected:
- OdysseyAppDelegate.swift (lines 37, 63, 80, 108)
- OdysseyApp.swift (lines 62, 65, 92)
- BackgroundSnapshotService.swift (lines 45, 67)
- DailyEntryViewModel.swift (lines 29, 102)

**Action:**
```swift
import os

let logger = Logger(subsystem: "com.johnlarkin.Odyssey", category: "DataPersistence")
logger.error("Failed to save entry: \(error)")
```

Consider also surfacing save failures to the user (toast notification or error state).

---

### 7. Fix Force Unwraps and Casts
**Status:** ⚠️ 3 crash risks
**Risk:** App could crash if unexpected state occurs
**Timeline:** 20 minutes

**AppDelegate.swift (lines 10, 15):**
```swift
// Before: force cast (crashes if wrong type)
task as! BGAppRefreshTask

// After:
guard let refreshTask = task as? BGAppRefreshTask else { return }
```

**MapVisualizationView.swift (lines 14-15):**
```swift
// Before:
let lat = entry.latitude!
let lng = entry.longitude!

// After:
guard let lat = entry.latitude, let lng = entry.longitude else { continue }
```

---

### 8. Wire Up ScreenTime App Selection Persistence
**Status:** ❌ Feature is non-functional
**Risk:** User selects apps but choices aren't saved
**Timeline:** 10 minutes

`ScreenTimeSelectAppsModel` has `saveSelection()` method but it's never called.

**Action:**
```swift
// ScreenTimeSelectAppsContentView.swift
.onChange(of: model.activitySelection) { oldValue, newValue in
    model.saveSelection()
}
```

---

### 9. Handle ModelContainer Initialization Failures Gracefully
**Status:** ⚠️ App crashes if migration fails
**Risk:** Cold starts could crash for users with corrupted data
**Timeline:** 30 minutes

Currently: `fatalError("Failed to create ModelContainer")` crashes on launch.

**Action:**
- Show error state UI instead of crashing
- Offer "Delete All Data" recovery option
- Log detailed error for debugging

---

### 10. Create Privacy Policy
**Status:** ❌ Missing
**Risk:** Submission blocked without URL
**Timeline:** 1-2 hours

Required by App Store Connect. Must disclose:
- Location collection (daily snapshot via reverse geocoding)
- HealthKit data (steps, walking distance, sleep)
- Screen Time data (for wellness insights)
- Photo library access
- Data stored locally on device only (no cloud, no sharing)
- **Critical for HealthKit:** "Health data is not used for advertising or sold to third parties"

**Recommendation:** Host on GitHub Pages (free, easy)
- Create `docs/privacy-policy.html`
- Reference in App Store Connect
- Example URL: `https://johnlarkin.github.io/odyssey/privacy`

---

## 🟢 MEDIUM PRIORITY (Quality improvements)

### 11. Wrap SampleData in #if DEBUG
**Status:** ⚠️ Dead code in production
**Timeline:** 5 minutes

`SampleData.swift` generates 30 fake entries; only used by preview container.

```swift
// Models/SampleData.swift
#if DEBUG
struct SampleData { ... }
#endif
```

---

### 12. Clean Up Production Code
- Replace legacy `PreviewProvider` with `#Preview` in `LottieView.swift` (line 40)
- Remove unused `CalendarHeatmapView.swift` or wire it into the Insights dashboard
- Fix `LottieView` animation replay issue (line 36 — wrap `play()` in state check)
- Consolidate duplicate mood gradient logic

---

### 13. Verify Location Permission Strings
**Status:** ⚠️ Potential discrepancy
**Timeline:** 5 minutes

Info.plist has one set of location descriptions; `project.pbxproj` has overrides. Verify they match in the final binary.

---

### 14. Set Encryption Export Compliance
**Status:** ⚠️ Missing
**Timeline:** 1 minute

Add to Info.plist:
```
ITSAppUsesNonExemptEncryption = NO
```

(Odyssey only uses HTTPS, which is exempt from export regulations.)

---

### 15. Remove or Migrate Legacy Core Data Model
**Status:** ⚠️ Adds binary size
**Timeline:** 15 minutes (after confirming migration is done)

`Odyssey.xcdatamodeld` is no longer used (migrated to SwiftData). Only remove after verifying all users have migrated.

---

## 📋 APP STORE METADATA CHECKLIST

### Build Configuration
- [ ] Marketing Version: `1.0`
- [ ] Build Number: `1` (increment for each submission)
- [ ] iOS Deployment Target: `17.0` (current)
- [ ] Xcode version: `16+` (required as of now)
- [ ] Build for Release configuration

### App Store Connect Metadata
- [ ] **App Name:** `Odyssey - Wellness Journal` (27 chars)
- [ ] **Subtitle:** `Mood Tracking & Daily Reflect` (30 chars)
- [ ] **Category:** Health & Fitness (primary), Lifestyle (secondary)
- [ ] **Keywords:** `journal,mood,tracker,wellness,mental,health,gratitude,mindful,diary,reflection,self-care,daily,log`

### Screenshots & Assets
- [ ] App Icon: 1024×1024 PNG (already exists: `odyssey.png`)
- [ ] 6 iPhone screenshots at 1320×2868 px (recommend 6.7" iPhone 15 Pro Max)
  1. Guided journaling flow (mood selection)
  2. Today tab with entry status
  3. Insights dashboard (mood trends chart)
  4. Map visualization (color-coded mood pins)
  5. Word cloud (journal themes)
  6. Year-in-Review (shareable cards)
- [ ] iPad screenshots (if supporting iPad; consider iPhone-only if iPad experience is poor)

### Description & Privacy
- [ ] **Description** (up to 4000 chars) — See marketing-assets-research for template
- [ ] **Privacy Policy URL** — Must be publicly accessible, mobile-friendly
- [ ] **Support URL** — With contact info (email or form)
- [ ] **Privacy Nutrition Labels** — Declare all data types (HealthKit, location, photos, screen time, journal entries)
  - Marked as "Data Not Linked to You" (since everything stays on-device)
  - "Data Not Used for Tracking"

### Age Rating & Compliance
- [ ] **Age Rating Questionnaire** — Complete in App Store Connect
  - Recommend: **4+** (wellness app, no objectionable content)
  - Note: Drinks/alcohol tracking might push to **9+**
- [ ] **FamilyControls Entitlement Approval** — Status: Pending
- [ ] **Export Compliance** — `ITSAppUsesNonExemptEncryption = NO`

---

## 🧪 TESTING BEFORE SUBMISSION

### Unit Tests
```bash
make test
```
- Ensure all tests pass
- No crashes in navigation flows

### Manual Testing on Physical Device
**Critical:** FamilyControls APIs don't work on simulator. Test on physical iPhone with:
- [ ] Daily journaling flow (all 8 steps)
- [ ] Background location capture (verify in maps)
- [ ] HealthKit integration (steps, sleep data visible)
- [ ] Screen Time capture (data persists across launches)
- [ ] Year-in-Review generation
- [ ] Data export and deletion

### TestFlight
1. Archive: `Xcode → Product → Archive`
2. Upload: `Organizer → Distribute App → App Store Connect`
3. Internal testing (no review needed, 24-48 hours to process)
4. External testing (requires Beta App Review, 24-48 hours)

---

## 📅 PUBLICATION TIMELINE

### Week 1: Blockers
- Day 1: **Submit FamilyControls entitlement requests** (all 3 bundle IDs)
- Day 1: **Create PrivacyInfo.xcprivacy**
- Day 1-2: **Fix critical code issues** (permissions, version string, force casts)
- Day 2-3: **Create privacy policy and host it**
- Day 3: **Create App Store metadata** (description, keywords, icon/screenshots)

### Week 2-6: Waiting + Validation (depends on entitlement approval)
- **During:** Integrate code fixes, run tests, prepare TestFlight builds
- **Once entitlement approved:** Upload to TestFlight
- **Internal testing:** 24-48 hours
- **External testing:** 24-48 hours (optional but recommended)

### Week 6+: App Store Submission
- Submit for App Review
- Review typically takes 24-48 hours
- Be ready for revision requests (add to revision plan below)

---

## 🔧 DETAILED CODE FIX CHECKLIST

Priority order (fastest to slowest):

```
1. Add ITSAppUsesNonExemptEncryption = NO           [1 min]
2. Fix hardcoded version string                      [5 min]
3. Fix photo library permission                      [5 min]
4. Fix location authorization flow                   [15 min]
5. Fix force casts in AppDelegate + MapView          [20 min]
6. Replace print() with os.Logger                    [30 min]
7. Wire ScreenTime app selection saveSelection()     [10 min]
8. Wrap SampleData in #if DEBUG                      [5 min]
9. Create PrivacyInfo.xcprivacy file                 [1 hour]
10. Handle ModelContainer failure gracefully          [30 min]
11. Fix location string consistency verification      [5 min]
12. Minor cleanup (PreviewProvider, duplicates, etc)  [30 min]

Total estimated time: 3-4 hours
```

---

## 📚 Key References

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Family Controls Entitlement](https://developer.apple.com/contact/request/family-controls-distribution)
- [Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Protecting User Privacy (HealthKit)](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [HealthKit Usage Compliance](https://developer.apple.com/app-store/review/guidelines/#healthkit)
- [App Store Submission Checklist](https://developer.apple.com/app-store/submitting/)

---

## ✅ GO/NO-GO DECISION FRAMEWORK

**GO to TestFlight once:**
- [ ] FamilyControls entitlement approved
- [ ] PrivacyInfo.xcprivacy created
- [ ] All critical code fixes applied
- [ ] Privacy policy published
- [ ] All unit tests passing
- [ ] Manual testing on physical device complete

**GO to App Store once:**
- [ ] TestFlight external testing passed
- [ ] App Store metadata complete
- [ ] No rejections from review team

---

## 🚀 POST-LAUNCH

- Monitor App Store reviews and crash reports
- Set up automated update testing (e.g., TestFlight beta builds)
- Plan v1.1 with community feedback
- Consider Android port (Flutter/React Native rewrite would be needed)
