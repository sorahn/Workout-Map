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
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    private func requestAuthorization() {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            requestAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            guard CLLocationManager.locationServicesEnabled() else { return }
            manager.requestLocation()
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            DispatchQueue.main.async {
                self.currentLocation = nil
            }
        @unknown default:
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
        DispatchQueue.main.async {
            self.currentLocation = nil
        }
    }
}
