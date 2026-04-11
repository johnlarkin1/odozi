import Foundation
#if os(iOS)
    import UIKit
#endif

#if DEBUG
    /// Deterministic fake data for DEBUG builds and App Store screenshot mode.
    ///
    /// Produces 30 past entries (yesterday → 30 days ago) with:
    /// - Dense New York City pin cluster plus a few travel days
    /// - Varied natural-voice journal text, gratitudes, wins, tensions
    /// - Dog-themed days (mood 8, photo attached) for the marketing narrative
    /// - Smooth mood curve so the Insights trend chart shows a real story
    /// - Procedural photo thumbnails (gradient + SF Symbol) stuffed into
    ///   `mapThumbnailData` so map pins show photos without Photos-library access
    ///
    /// All content is deterministic — same launch produces identical data, so
    /// App Store screenshots are reproducible across rebuilds.
    enum SampleData {
        static var entries: [DailyEntry] {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            return (1 ... 30).reversed().map { daysAgo in
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
                let i = daysAgo - 1 // 0-indexed for array lookups

                let loc = location(for: i)

                // Optional overrides loaded from SampleAssets/day_NN/ on disk.
                // Fall back to the hardcoded values when a file isn't present.
                #if os(iOS)
                    let journalOverride = loadJournalOverride(forDaysAgo: daysAgo)
                    let moodOverride = loadMoodOverride(forDaysAgo: daysAgo)
                #else
                    let journalOverride: String? = nil
                    let moodOverride: Int? = nil
                #endif

                let mood = moodOverride ?? moodValue(for: i)
                let journalText = journalOverride ?? journals[i]

                let entry = DailyEntry(
                    date: date,
                    feeling: mood,
                    singleWordFeeling: singleWords[i],
                    feelingColorHex: feelingColor(for: mood),
                    sleepQuality: sleepQualities[i],
                    gratitude: gratitudes[i],
                    win: wins[i],
                    tension: tensions[i],
                    journalEntry: journalText,
                    drinks: i % 6 == 0 ? 2 : 0,
                    latitude: loc.latitude,
                    longitude: loc.longitude,
                    city: loc.city,
                    state: loc.state,
                    country: "US",
                    stepCount: 4_000 + (i * 347) % 10_000,
                    walkingDistanceMeters: 3_000 + Double((i * 291) % 8_000),
                    sleepHours: 6.5 + Double(i % 6) * 0.4,
                    screenTimeSeconds: Double(3_600 + (i * 619) % 18_000),
                    pickups: 30 + (i * 7) % 90
                )

                // Mark as submitted so streaks, trends, and achievements populate.
                entry.hasUserSubmitted = true
                entry.firstSubmittedAt = calendar.date(byAdding: .hour, value: 21, to: date)
                entry.locationCapturedAt = calendar.date(byAdding: .hour, value: 12, to: date)
                entry.createdAt = date
                entry.updatedAt = date

                // Attach photo(s) on photo days. Supports multiple files per day:
                // any file in the folder matching `photo*.{jpg,jpeg,png,heic}` is
                // loaded and added to attachedPhotoData. Falls back to a single
                // procedural thumbnail if the folder is empty.
                #if os(iOS)
                    if let (thumb, fulls) = photoData(forDaysAgo: daysAgo, i: i) {
                        entry.mapThumbnailData = thumb
                        entry.attachedPhotoData = fulls
                        entry.showOnPhotoMap = true
                    }
                #endif

                return entry
            }
        }

        // MARK: - Journal content (30 items each, index = daysAgo - 1)

        private static let journals: [String] = [
            // 0 = yesterday — dog day, mood 8
            "Saw a cute dog today. Little corgi in Central Park, kept chasing her own tail. Made my whole afternoon.",
            "Long walk before work. Felt grounded for the first time in a week.",
            "Back-to-back meetings but squeezed in coffee with Sam. Worth it.",
            "Weekend getaway to San Francisco. Dim sum, walked the hills, crashed at 9.",
            "Sunset from the rooftop was unreal. Stopped everything to watch it.",
            "Shipped the new feature. Weeks of work finally out in the world.",
            // 6 — dog day
            "Puppy at the coffee shop kept staring at my croissant. Ended up sharing a corner. Mood: restored.",
            "Rough day at work but a run along the Hudson cleared my head.",
            "Flew out to Chicago for a friend's wedding. Dance floor was packed.",
            "Rainy day in Chicago. Stayed in with the bridal party. Made soup.",
            "Back in NYC. Read an entire chapter before bed. Phone in the other room.",
            "Quiet Sunday in Prospect Park. Tried to identify every tree.",
            "Big presentation went well. Team was happy. Slept easy.",
            "Didn't sleep great. Dragged all day. Made it anyway.",
            // 14 — dog day
            "Saw a cute dog today in the East Village. Bernese mountain dog, absolute unit. Owner let me say hi.",
            "Productive morning at the café. Three deliverables done by noon.",
            "Called Mom. Laughed more than I have all week.",
            "Hit a new personal best at the gym. Felt unstoppable for 10 minutes.",
            "Quick LA trip. Tacos, beach time, decompression.",
            "Farmer's market run. Fresh flowers, homemade bread. Simple joys.",
            "Work was overwhelming but grateful for supportive colleagues.",
            "Spent the evening sketching ideas for the side project. Creative flow.",
            // 22 — dog day
            "Saw the cutest golden retriever on the High Line. Stopped to pet him. Full body tail wag. Day made.",
            "Tough conversation today but it needed to happen.",
            "Boston for the weekend. Walked the Freedom Trail. Cold, crisp air.",
            "Boston → home. Train ride was peaceful. Watched the coast roll by.",
            "Early morning yoga set the whole day right.",
            // 27 — dog day
            "March in NYC, what a dream. Took these pics of Nali",
            "Made real progress on the thing I've been putting off.",
            "Finished the book I started last month. Already miss the characters.",
        ]

        private static let gratitudes: [String] = [
            "The corgi in the park",
            "My morning coffee ritual",
            "An unexpected compliment",
            "Good friends who pick up",
            "The sunset tonight",
            "Finishing what I started",
            "Shared pastry with a puppy",
            "Runs by the water",
            "Friends who host",
            "Slow rainy days",
            "Quiet apartments",
            "Trees I can't name yet",
            "Supportive teammates",
            "Enough sleep to function",
            "Bernese mountain dog hugs",
            "Cafés that let you linger",
            "Mom's laugh",
            "New personal bests",
            "Tacos by the ocean",
            "Fresh flowers on the table",
            "Colleagues who notice",
            "Creative flow",
            "Golden retrievers",
            "Hard conversations handled",
            "Cold, crisp air",
            "Train windows and coastlines",
            "Yoga first thing",
            "Dachshunds in jackets",
            "Small steps forward",
            "Great last pages",
        ]

        private static let wins: [String] = [
            "Took the long way home",
            "Closed all my rings",
            "Replied to every email",
            "Packed light",
            "Watched the whole sunset",
            "Shipped the feature",
            "Said hi to the dog",
            "Ran 3 miles",
            "Made it to the wedding",
            "Stayed in with no guilt",
            "Read 50 pages",
            "Got outside before noon",
            "Nailed the presentation",
            "Made it through on no sleep",
            "Asked to pet the dog",
            "Finished three things",
            "Called instead of texted",
            "New PR at the gym",
            "Took the trip",
            "Bought myself flowers",
            "Asked for help",
            "Filled two sketchbook pages",
            "Stopped to pet the retriever",
            "Said the hard thing kindly",
            "Walked the trail",
            "Didn't scroll on the train",
            "Made the 7am class",
            "Gave a real compliment",
            "Started the thing",
            "Finished the book",
        ]

        private static let tensions: [String] = [
            "", "", "Work deadline creeping in", "", "",
            "", "", "Bad sleep", "", "Missing home",
            "", "", "", "Low energy", "",
            "", "", "Can't shake that meeting", "", "",
            "Overwhelmed by the todo list", "", "", "Hard talk ahead", "",
            "", "", "", "", "",
        ]

        private static let singleWords: [String] = [
            "delighted", "grounded", "focused", "curious", "awed",
            "accomplished", "warm", "clear-headed", "celebratory", "cozy",
            "steady", "peaceful", "proud", "weary", "smitten",
            "productive", "connected", "strong", "relaxed", "content",
            "supported", "inspired", "joyful", "honest", "invigorated",
            "reflective", "centered", "tickled", "motivated", "satisfied",
        ]

        private static let sleepQualities: [Int] = [
            8, 7, 6, 7, 8, 7, 8, 5, 8, 6,
            7, 8, 7, 4, 8, 7, 7, 8, 7, 7,
            6, 7, 8, 6, 7, 8, 8, 8, 7, 8,
        ]

        // MARK: - Location

        /// Days (0-indexed) where the user was traveling outside NYC.
        /// Order matches the sorted iteration of the set.
        private static let travelDays: [Int] = [2, 8, 9, 17, 23, 24]

        /// Travel destinations, indexed parallel to travelDays.
        private static let travelDestinations: [(lat: Double, lng: Double, city: String, state: String)] = [
            (37.7749, -122.4194, "San Francisco", "CA"), // day 2
            (41.8781, -87.6298, "Chicago", "IL"), // day 8
            (41.8781, -87.6298, "Chicago", "IL"), // day 9
            (34.0522, -118.2437, "Los Angeles", "CA"), // day 17
            (42.3601, -71.0589, "Boston", "MA"), // day 23
            (42.3601, -71.0589, "Boston", "MA"), // day 24
        ]

        /// NYC spots spread across all 5 boroughs. Indexed by `i % count`.
        /// Photo days land at these positions after `daysAgo - 1` mod:
        ///   i=0  (day_01, dog) → idx 0  = Central Park, Manhattan
        ///   i=6  (day_07, dog) → idx 6  = Williamsburg, Brooklyn (coffee shop)
        ///   i=14 (day_15, dog) → idx 14 = Prospect Park, Brooklyn
        ///   i=22 (day_23, dog) → idx 22 = Astoria Park, Queens
        ///   i=27 (day_28, dog) → idx 3  = Washington Square, Manhattan
        ///   i=4  (day_05, scene) → idx 4 = High Line, Manhattan
        ///   i=11 (day_12, scene) → idx 11 = Forest Park, Queens
        private static let nycSpots: [(lat: Double, lng: Double)] = [
            (40.7829, -73.9654), //  0 Central Park — Manhattan          ← day_01 🐕
            (40.7580, -73.9855), //  1 Times Square — Manhattan
            (40.7484, -73.9857), //  2 Empire State — Manhattan
            (40.7308, -73.9973), //  3 Washington Square — Manhattan     ← day_28 🐕
            (40.7480, -74.0048), //  4 High Line — Manhattan             ← day_05 🌇
            (40.7033, -74.0170), //  5 Battery Park — Manhattan
            (40.7081, -73.9571), //  6 Williamsburg — Brooklyn           ← day_07 🐕 (coffee)
            (40.7033, -73.9881), //  7 DUMBO — Brooklyn
            (40.6974, -73.9964), //  8 Brooklyn Heights — Brooklyn
            (40.7128, -74.0060), //  9 Financial District — Manhattan
            (40.7447, -73.9485), // 10 Long Island City — Queens
            (40.7004, -73.8502), // 11 Forest Park — Queens              ← day_12 🍃
            (40.7736, -73.9566), // 12 Upper East Side — Manhattan
            (40.8116, -73.9465), // 13 Harlem — Manhattan
            (40.6602, -73.9690), // 14 Prospect Park — Brooklyn          ← day_15 🐕
            (40.6710, -73.9814), // 15 Park Slope — Brooklyn
            (40.7464, -73.8458), // 16 Flushing Meadows — Queens
            (40.7336, -74.0027), // 17 Greenwich Village — Manhattan
            (40.5755, -73.9707), // 18 Coney Island — Brooklyn
            (40.8506, -73.8770), // 19 Bronx Zoo — Bronx
            (40.6580, -73.9928), // 20 Green-Wood Cemetery — Brooklyn
            (40.8976, -73.8859), // 21 Van Cortlandt Park — Bronx
            (40.7799, -73.9235), // 22 Astoria Park — Queens             ← day_23 🐕
            (40.6437, -74.0731), // 23 St. George — Staten Island
        ]

        private static func location(for i: Int) -> (latitude: Double, longitude: Double, city: String, state: String) {
            if let travelIndex = travelDays.firstIndex(of: i) {
                let spot = travelDestinations[travelIndex]
                return (spot.lat, spot.lng, spot.city, spot.state)
            }
            let spot = nycSpots[i % nycSpots.count]
            // Tiny deterministic jitter so pins don't stack exactly.
            let jitterLat = Double((i * 13) % 41 - 20) / 50_000.0
            let jitterLng = Double((i * 17) % 37 - 18) / 50_000.0
            return (spot.lat + jitterLat, spot.lng + jitterLng, "New York", "NY")
        }

        // MARK: - Mood

        /// Dog days always 8. Other days follow a smooth sine curve around 6-7 with
        /// small deterministic variation so the trend chart has visible shape.
        private static func moodValue(for i: Int) -> Int {
            if dogDays.contains(i) { return 8 }
            let wave = sin(Double(i) * 0.45) * 1.5
            let offset = Double((i * 37) % 9) / 9.0 - 0.5
            let raw = 6.5 + wave + offset
            return max(4, min(9, Int(raw.rounded())))
        }

        private static func feelingColor(for mood: Int) -> String {
            switch mood {
            case ...3: return "#E57373" // coral
            case 4 ... 5: return "#FFD54F" // soft amber
            case 6 ... 7: return "#F5A623" // accent amber
            case 8: return "#2EC4B6" // teal
            default: return "#4CAF50" // green
            }
        }

        // MARK: - Procedural photos

        /// Days with cute-dog photos attached (mood 8).
        private static let dogDays: Set<Int> = [0, 6, 14, 22, 27]

        /// Other days with a scenic photo attached.
        private static let otherPhotoDays: Set<Int> = [4, 11]

        #if os(iOS)
            // SampleAssets/day_NN/photo.*     → map pin thumbnail + detail card attachment
            // SampleAssets/day_NN/journal.txt → overrides journals[i] (optional)
            // SampleAssets/day_NN/mood.txt    → single int 1–10 overrides the mood (optional)
            //
            // All three are optional. Missing files fall through to the hardcoded
            // content and procedural photo thumbnails.

            private static func photoData(forDaysAgo daysAgo: Int, i: Int) -> (thumb: Data, fulls: [Data])? {
                guard dogDays.contains(i) || otherPhotoDays.contains(i) else { return nil }
                // Only attach photos when we have real ones bundled under SampleAssets/day_NN/.
                // Days without a real photo just show as regular mood pins — matching the
                // actual app behavior (no procedural icons in production).
                return loadSampleAssetPhotos(forDaysAgo: daysAgo)
            }

            /// Resolves the `SampleAssets/` folder inside the app bundle.
            /// A Run Script Build Phase copies `$SRCROOT/SampleAssets/` into the
            /// bundle during DEBUG builds only, so personal photos never end up
            /// in the shipped App Store binary. The iOS Simulator sandbox blocks
            /// directory enumeration on arbitrary host paths, so we cannot load
            /// them via `#filePath` at runtime — Bundle.main is the only reliable
            /// path that survives the sandbox.
            private static let sampleAssetsDirectory: URL = {
                Bundle.main.bundleURL.appendingPathComponent("SampleAssets", isDirectory: true)
            }()

            /// `SampleAssets/day_NN/` for a given daysAgo value.
            private static func sampleDayDirectory(forDaysAgo daysAgo: Int) -> URL {
                let folder = String(format: "day_%02d", daysAgo)
                return sampleAssetsDirectory.appendingPathComponent(folder, isDirectory: true)
            }

            /// Photo extensions tried in order when looking for `photo.*` in a day folder.
            private static let photoExtensions = ["jpg", "jpeg", "png", "heic", "HEIC", "JPG", "JPEG", "PNG"]

            /// Read `SampleAssets/day_NN/journal.txt` if present.
            private static func loadJournalOverride(forDaysAgo daysAgo: Int) -> String? {
                let url = sampleDayDirectory(forDaysAgo: daysAgo).appendingPathComponent("journal.txt")
                guard FileManager.default.fileExists(atPath: url.path),
                      let raw = try? String(contentsOf: url, encoding: .utf8)
                else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

            /// Read `SampleAssets/day_NN/mood.txt` if present. Must parse as Int in 1...10.
            private static func loadMoodOverride(forDaysAgo daysAgo: Int) -> Int? {
                let url = sampleDayDirectory(forDaysAgo: daysAgo).appendingPathComponent("mood.txt")
                guard FileManager.default.fileExists(atPath: url.path),
                      let raw = try? String(contentsOf: url, encoding: .utf8)
                else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let value = Int(trimmed), (1 ... 10).contains(value) else { return nil }
                return value
            }

            /// Finds every file in the day folder named `photo*` with a supported
            /// extension (jpg/jpeg/png/heic, case-insensitive), sorted alphabetically
            /// so `photo.jpg` < `photo_2.jpg` < `photo_3.jpg`. Returns the first
            /// image's thumbnail plus all full-size images for `attachedPhotoData`.
            private static func loadSampleAssetPhotos(forDaysAgo daysAgo: Int) -> (thumb: Data, fulls: [Data])? {
                let dir = sampleDayDirectory(forDaysAgo: daysAgo)
                guard FileManager.default.fileExists(atPath: dir.path),
                      let contents = try? FileManager.default.contentsOfDirectory(atPath: dir.path)
                else { return nil }

                let lowercased = Set(photoExtensions.map { $0.lowercased() })
                let photoFiles = contents
                    .filter { name in
                        guard name.lowercased().hasPrefix("photo") else { return false }
                        let ext = (name as NSString).pathExtension.lowercased()
                        return lowercased.contains(ext)
                    }
                    .sorted()

                guard !photoFiles.isEmpty else { return nil }

                var fullImages: [Data] = []
                var thumb: Data?

                for name in photoFiles {
                    let url = dir.appendingPathComponent(name)
                    guard let rawData = try? Data(contentsOf: url),
                          let uiImage = UIImage(data: rawData)
                    else { continue }

                    let full = resizedJPEG(image: uiImage, maxDimension: 1_200) ?? rawData
                    fullImages.append(full)

                    if thumb == nil {
                        thumb = resizedJPEG(image: uiImage, maxDimension: 200) ?? full
                    }
                }

                guard let firstThumb = thumb, !fullImages.isEmpty else { return nil }
                return (firstThumb, fullImages)
            }

            private static func resizedJPEG(image: UIImage, maxDimension: CGFloat) -> Data? {
                let w = image.size.width
                let h = image.size.height
                guard w > 0, h > 0 else { return nil }
                let scale = min(maxDimension / w, maxDimension / h, 1.0)
                let newSize = CGSize(width: w * scale, height: h * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                let rendered = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: newSize))
                }
                return rendered.jpegData(compressionQuality: 0.85)
            }

        #endif
    }
#endif
