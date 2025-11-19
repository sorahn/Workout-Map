//
//  WorkoutRoute.swift
//  Workout Map
//
//  Created by Codex on 11/18/25.
//

import Foundation
import MapKit
import SwiftUI

/// Simple model that represents a workout route loaded from HealthKit or local data.
struct WorkoutRoute: Identifiable {
    let id = UUID()
    let name: String
    let distanceInKilometers: Double
    let coordinates: [CLLocationCoordinate2D]
    let color: Color

    var formattedDistance: String {
        WorkoutRoute.formatDistance(distanceInKilometers)
    }

    static func formatDistance(_ kilometers: Double) -> String {
        distanceFormatter.string(
            from: Measurement(value: kilometers, unit: UnitLength.kilometers)
        )
    }

    private static let distanceFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .short
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()
}

// MARK: - Sample data

enum WorkoutDataProvider {
    /// In a real implementation you would fetch from HealthKit. For now we provide sample data.
    static let sampleRoutes: [WorkoutRoute] = [
        WorkoutRoute(
            name: "Neighborhood Tempo",
            distanceInKilometers: 5.4,
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                CLLocationCoordinate2D(latitude: 37.3300, longitude: -122.0250),
                CLLocationCoordinate2D(latitude: 37.3245, longitude: -122.0331),
                CLLocationCoordinate2D(latitude: 37.3188, longitude: -122.0294),
                CLLocationCoordinate2D(latitude: 37.3229, longitude: -122.0159),
                CLLocationCoordinate2D(latitude: 37.3304, longitude: -122.0084)
            ],
            color: .blue
        ),
        WorkoutRoute(
            name: "Trail Climb",
            distanceInKilometers: 7.8,
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.3700, longitude: -122.0860),
                CLLocationCoordinate2D(latitude: 37.3644, longitude: -122.0770),
                CLLocationCoordinate2D(latitude: 37.3582, longitude: -122.0791),
                CLLocationCoordinate2D(latitude: 37.3520, longitude: -122.0901),
                CLLocationCoordinate2D(latitude: 37.3460, longitude: -122.1015),
                CLLocationCoordinate2D(latitude: 37.3508, longitude: -122.1110),
                CLLocationCoordinate2D(latitude: 37.3590, longitude: -122.1032)
            ],
            color: .green
        ),
        WorkoutRoute(
            name: "Recovery Spin",
            distanceInKilometers: 12.3,
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.7926, longitude: -122.4040),
                CLLocationCoordinate2D(latitude: 37.7869, longitude: -122.4194),
                CLLocationCoordinate2D(latitude: 37.7817, longitude: -122.4321),
                CLLocationCoordinate2D(latitude: 37.7709, longitude: -122.4370),
                CLLocationCoordinate2D(latitude: 37.7623, longitude: -122.4282),
                CLLocationCoordinate2D(latitude: 37.7687, longitude: -122.4150),
                CLLocationCoordinate2D(latitude: 37.7776, longitude: -122.4057),
                CLLocationCoordinate2D(latitude: 37.7852, longitude: -122.4019)
            ],
            color: .orange
        )
    ]
}

// MARK: - Helpers

extension Collection where Element == WorkoutRoute {
    /// Creates a map region that fits all routes with optional visual padding.
    func combinedRegion(paddingFactor: Double = 0.3) -> MKCoordinateRegion? {
        let coordinates = flatMap(\.coordinates)
        guard let firstCoordinate = coordinates.first else {
            return nil
        }

        var minLatitude = firstCoordinate.latitude
        var maxLatitude = firstCoordinate.latitude
        var minLongitude = firstCoordinate.longitude
        var maxLongitude = firstCoordinate.longitude

        for coordinate in coordinates {
            minLatitude = Swift.min(minLatitude, coordinate.latitude)
            maxLatitude = Swift.max(maxLatitude, coordinate.latitude)
            minLongitude = Swift.min(minLongitude, coordinate.longitude)
            maxLongitude = Swift.max(maxLongitude, coordinate.longitude)
        }

        let latitudeDelta = Swift.max((maxLatitude - minLatitude) * (1 + paddingFactor), 0.01)
        let longitudeDelta = Swift.max((maxLongitude - minLongitude) * (1 + paddingFactor), 0.01)

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        return MKCoordinateRegion(center: center, span: span)
    }

    var totalDistance: Double {
        reduce(0) { $0 + $1.distanceInKilometers }
    }
}
