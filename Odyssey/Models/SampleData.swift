import Foundation

#if DEBUG
    enum SampleData {
        static var entries: [DailyEntry] {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())

            return (0 ..< 30).map { daysAgo in
                let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
                let feeling = Int.random(in: 3 ... 9)
                let words = ["grateful", "tired", "energized", "calm", "anxious", "hopeful", "content", "driven", "peaceful", "excited"]
                let colors = ["#F5A623", "#2EC4B6", "#4CAF50", "#E57373", "#64B5F6", "#FFD54F", "#81C784", "#BA68C8"]
                let gratitudes = [
                    "Morning coffee with a friend",
                    "Beautiful sunset on my walk",
                    "Got a great night's sleep",
                    "Finished a challenging project",
                    "Had a meaningful conversation",
                    "Enjoyed a home-cooked meal",
                ]
                let wins = [
                    "Completed my workout",
                    "Shipped a new feature",
                    "Read for 30 minutes",
                    "Cooked a healthy dinner",
                    "Had a productive morning",
                    "Helped a colleague",
                ]

                // Ohio city coordinates with tight offsets to keep pins on land
                let locations: [(lat: Double, lng: Double, city: String)] = [
                    (39.1031, -84.5120, "Cincinnati"),
                    (41.4993, -81.6944, "Cleveland"),
                    (39.9612, -82.9988, "Columbus"),
                    (40.7989, -81.3784, "Canton"),
                    (39.7589, -84.1916, "Dayton"),
                    (41.6528, -83.5379, "Toledo"),
                ]
                let loc = locations[daysAgo % locations.count]

                return DailyEntry(
                    date: date,
                    feeling: feeling,
                    singleWordFeeling: words.randomElement()!,
                    feelingColorHex: colors.randomElement()!,
                    sleepQuality: Int.random(in: 4 ... 9),
                    gratitude: gratitudes.randomElement()!,
                    win: wins.randomElement()!,
                    tension: daysAgo % 3 == 0 ? "Work deadline stress" : "",
                    journalEntry: daysAgo % 2 == 0 ? "Today was a good day overall. I felt productive and connected." : "",
                    drinks: Int.random(in: 0 ... 3),
                    latitude: loc.lat + Double.random(in: -0.05 ... 0.05),
                    longitude: loc.lng + Double.random(in: -0.05 ... 0.05),
                    city: loc.city,
                    state: "OH",
                    country: "US",
                    stepCount: Int.random(in: 3000 ... 15000),
                    walkingDistanceMeters: Double.random(in: 2000 ... 12000),
                    sleepHours: Double.random(in: 5.5 ... 9.0),
                    screenTimeSeconds: Double.random(in: 3600 ... 28800),
                    pickups: Int.random(in: 20 ... 120)
                )
            }
        }
    }
#endif
