//
//  DailyEntryViewModel.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import SwiftUI
import CoreData

class DailyEntryViewModel: ObservableObject {
    private let context = PersistenceController.shared.container.viewContext
    @Published var hasSubmittedData = false
    @Published var submissionMessage = ""

    init() {
        checkForTodayEntry() // Check for today's entry when the ViewModel is initialized
    }

    func checkForTodayEntry() {
        let today = Calendar.current.startOfDay(for: Date())
        let fetchRequest: NSFetchRequest<DailyEntry> = DailyEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", today as NSDate)
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            DispatchQueue.main.async {
                if !results.isEmpty {
                    self.hasSubmittedData = true
                    self.submissionMessage = "Already completed entry for today."
                } else {
                    self.hasSubmittedData = false
                }
            }
        } catch {
            print("Failed to fetch data for today: \(error)")
        }
    }

    func submitData(feeling: Double, sleepQuality: Double, singleWordFeeling: String, feelingColor: Color, journalEntry: String, drinks: Int, win: String, tension: String, gratitude: String) {
        let today = Calendar.current.startOfDay(for: Date())
        let fetchRequest: NSFetchRequest<DailyEntry> = DailyEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", today as NSDate)
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            let entry: DailyEntry
            if results.isEmpty {
                // No existing entry with this date, create a new one
                entry = DailyEntry(context: context)
                entry.date = today
            } else {
                // An entry already exists with this date, update it
                entry = results.first!
            }

            // Convert the SwiftUI Color to UIColor then to a hex string
            let uiColor = UIColor(feelingColor)
            let colorHex = uiColor.toHexString()

            // Set properties for both new and existing entries
            entry.feeling = Int16(feeling)
            entry.sleepQuality = Int16(sleepQuality)
            entry.singleWordFeeling = singleWordFeeling
            entry.feelingColor = colorHex  // Save the hex string
            entry.journalEntry = journalEntry
            entry.drinks = Int16(drinks)
            entry.win = win
            entry.tension = tension
            entry.gratitude = gratitude

            try context.save()
            DispatchQueue.main.async {
                self.hasSubmittedData = true
                self.submissionMessage = "Successfully saved today's entry."
            }
        } catch {
            print("Failed to save or update the entry: \(error)")
        }
    }

}
