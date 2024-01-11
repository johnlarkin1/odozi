//
//  BackgroundDataFetch.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import Foundation
import CoreLocation
import CoreData

class BackgroundDataFetch: Operation, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
    }

    override func main() {
        if isCancelled { return }

        // Set up the location manager
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization() // For background location access
        locationManager.startUpdatingLocation()

        // Wait for location updates
        while currentLocation == nil && !isCancelled {
            sleep(1) // Wait for 1 second before checking again
        }

        // Fetch the data
        if let location = currentLocation {
            fetchLocationData(location)
        }
        fetchScreenTimeData()
        fetchPhonePickupsData()

        // Complete the operation
        completeOperation()
    }

    private func fetchLocationData(_ location: CLLocation) {
        let today = Calendar.current.startOfDay(for: Date())
        let fetchRequest: NSFetchRequest<DailyEntry> = DailyEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date == %@", today as NSDate)
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            let dailyEntry: DailyEntry
            if results.isEmpty {
                // No existing entry for today, create a new one
                dailyEntry = DailyEntry(context: context)
                dailyEntry.date = today
            } else {
                // Update the existing entry
                dailyEntry = results.first!
            }

            // Update the location data
            dailyEntry.latitude = location.coordinate.latitude
            dailyEntry.longitude = location.coordinate.longitude

            try context.save()
        } catch {
            print("Error saving location to Core Data: \(error)")
        }
    }

    private func fetchScreenTimeData() {
        // Implement screen time fetching logic here
    }

    private func fetchPhonePickupsData() {
        // Implement phone pickups fetching logic here
    }

    private func completeOperation() {
        if isCancelled { return }
        // Complete any final tasks before the operation finishes
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.currentLocation = locations.last
        locationManager.stopUpdatingLocation() // Stop location updates if needed
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to fetch location: \(error.localizedDescription)")
    }
}
