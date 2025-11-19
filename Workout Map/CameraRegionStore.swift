//
//  CameraRegionStore.swift
//  Workout Map
//
//  Created by Codex on 11/18/25.
//

import Foundation
import MapKit

struct CameraRegionStore {
    private let storageKey = "com.codex.workoutmap.camera-region"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadRegion() -> MKCoordinateRegion? {
        guard let data = userDefaults.data(forKey: storageKey),
              let stored = try? decoder.decode(StoredRegion.self, from: data) else {
            return nil
        }
        return stored.region
    }

    func saveRegion(_ region: MKCoordinateRegion) {
        guard let data = try? encoder.encode(StoredRegion(region: region)) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

private struct StoredRegion: Codable {
    let centerLatitude: Double
    let centerLongitude: Double
    let spanLatitudeDelta: Double
    let spanLongitudeDelta: Double

    init(region: MKCoordinateRegion) {
        centerLatitude = region.center.latitude
        centerLongitude = region.center.longitude
        spanLatitudeDelta = region.span.latitudeDelta
        spanLongitudeDelta = region.span.longitudeDelta
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude),
            span: MKCoordinateSpan(latitudeDelta: spanLatitudeDelta, longitudeDelta: spanLongitudeDelta)
        )
    }
}
