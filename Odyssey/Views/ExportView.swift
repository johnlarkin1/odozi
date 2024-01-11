//
//  ExportView.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import SwiftUI
import CoreData
import DeviceActivity

struct ExportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var context: DeviceActivityReport.Context = .init(rawValue: "Total Activity")

    @State private var filter = DeviceActivityFilter(
        segment: .daily(
            during: Calendar.current.dateInterval(
               of: .day, for: .now
            )!
        ),
        users: .all,
        devices: .init([.iPhone, .iPad])
    )

    var body: some View {
        VStack {
//            Button("Export Data", action: exportData)
            DeviceActivityReport(context, filter: filter)
        }
        .navigationBarTitle("Export Data", displayMode: .inline)
    }

    func exportData() {
        // 1. Fetch CoreData data
        let fetchRequest: NSFetchRequest<DailyEntry> = DailyEntry.fetchRequest()
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            let fileURL = try convertToCSV(entries: results)
            shareFile(fileURL: fileURL)
        } catch {
            print("Error fetching or exporting data: \(error)")
        }
    }

    private func convertToCSV(entries: [DailyEntry]) throws -> URL {
        let fileName = "exportedData.csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        var csvText = "Date,Feeling,Sleep Quality,Single Word Feeling,Journal Entry,Drinks,Win,Tension,Gratitude\n"

        for entry in entries {
            let csvLine = "\(entry.date!),\(entry.feeling),\(entry.sleepQuality),\(entry.singleWordFeeling ?? ""),\(entry.journalEntry ?? ""),\(entry.drinks),\(entry.win ?? ""),\(entry.tension ?? ""),\(entry.gratitude ?? "")\n"
            csvText.append(contentsOf: csvLine)
        }

        try csvText.write(to: path, atomically: true, encoding: String.Encoding.utf8)
        return path
    }

    private func shareFile(fileURL: URL) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

        // Finding the key window using UIWindowScene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityViewController, animated: true, completion: nil)
        }
    }
}


struct ExportView_Previews: PreviewProvider {
    static var previews: some View {
        ExportView()
    }
}
