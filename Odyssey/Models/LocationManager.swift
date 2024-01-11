//
//  LocationManager.swift
//  Odyssey
//
//  Created by John Larkin on 1/6/24.
//

import CoreLocation

class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?

    override init() {
    super.init()
    self.locationManager.delegate = self
    self.locationManager.requestWhenInUseAuthorization()
    self.locationManager.startUpdatingLocation()
  }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }
}
