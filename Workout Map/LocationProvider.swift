//
//  LocationProvider.swift
//  Workout Map
//
//  Created by Codex on 11/18/25.
//

import Combine
import CoreLocation
import Foundation

final class LocationProvider: NSObject, ObservableObject {
    @Published private(set) var currentLocation: CLLocation?

    private let manager = CLLocationManager()
    private var hasRequestedAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        requestAuthorizationIfNeeded()
    }

    private func requestAuthorizationIfNeeded() {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        manager.requestWhenInUseAuthorization()
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if CLLocationManager.locationServicesEnabled() {
                manager.startUpdatingLocation()
            }
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            DispatchQueue.main.async {
                self.currentLocation = nil
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = latest
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignore transient errors but clear last location so the UI can fall back gracefully.
        DispatchQueue.main.async {
            self.currentLocation = nil
        }
    }
}
