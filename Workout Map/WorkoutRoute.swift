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
    let id: UUID
    let workoutIdentifier: UUID?
    let name: String
    let distanceInKilometers: Double
    let startDate: Date
    let coordinates: [CLLocationCoordinate2D]
    let routeColor: RouteColor

    init(
        id: UUID = UUID(),
        workoutIdentifier: UUID? = nil,
        name: String,
        distanceInKilometers: Double,
        startDate: Date = Date(),
        coordinates: [CLLocationCoordinate2D],
        color: RouteColor
    ) {
        self.id = id
        self.workoutIdentifier = workoutIdentifier
        self.name = name
        self.distanceInKilometers = distanceInKilometers
        self.startDate = startDate
        self.coordinates = coordinates
        self.routeColor = color
    }

    var color: Color {
        routeColor.color
    }

    var strokeStyle: LinearGradient {
        routeColor.gradientStyle
    }

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
            workoutIdentifier: UUID(),
            name: "Neighborhood Tempo",
            distanceInKilometers: 5.4,
            startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                CLLocationCoordinate2D(latitude: 37.3300, longitude: -122.0250),
                CLLocationCoordinate2D(latitude: 37.3245, longitude: -122.0331),
                CLLocationCoordinate2D(latitude: 37.3188, longitude: -122.0294),
                CLLocationCoordinate2D(latitude: 37.3229, longitude: -122.0159),
                CLLocationCoordinate2D(latitude: 37.3304, longitude: -122.0084)
            ],
            color: .sunrise
        ),
        WorkoutRoute(
            workoutIdentifier: UUID(),
            name: "Trail Climb",
            distanceInKilometers: 7.8,
            startDate: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
            coordinates: [
                CLLocationCoordinate2D(latitude: 37.3700, longitude: -122.0860),
                CLLocationCoordinate2D(latitude: 37.3644, longitude: -122.0770),
                CLLocationCoordinate2D(latitude: 37.3582, longitude: -122.0791),
                CLLocationCoordinate2D(latitude: 37.3520, longitude: -122.0901),
                CLLocationCoordinate2D(latitude: 37.3460, longitude: -122.1015),
                CLLocationCoordinate2D(latitude: 37.3508, longitude: -122.1110),
                CLLocationCoordinate2D(latitude: 37.3590, longitude: -122.1032)
            ],
            color: .seafoam
        ),
        WorkoutRoute(
            workoutIdentifier: UUID(),
            name: "Recovery Spin",
            distanceInKilometers: 12.3,
            startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
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
            color: .lavender
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

// MARK: - Route color helpers

extension WorkoutRoute {
    enum RouteColor: String, Codable, CaseIterable {
        case sunrise
        case peach
        case seafoam
        case lavender
        case sky
        case mint
        case butter
        case rose

        var color: Color {
            gradientColors.first ?? .blue
        }

        var gradientStyle: LinearGradient {
            LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
        }

        private var gradientColors: [Color] {
            switch self {
            case .sunrise:
                return [
                    Color(red: 1.0, green: 0.87, blue: 0.80),
                    Color(red: 1.0, green: 0.73, blue: 0.63)
                ]
            case .peach:
                return [
                    Color(red: 1.0, green: 0.82, blue: 0.73),
                    Color(red: 0.99, green: 0.70, blue: 0.60)
                ]
            case .seafoam:
                return [
                    Color(red: 0.78, green: 0.93, blue: 0.88),
                    Color(red: 0.64, green: 0.84, blue: 0.79)
                ]
            case .lavender:
                return [
                    Color(red: 0.87, green: 0.84, blue: 0.96),
                    Color(red: 0.74, green: 0.71, blue: 0.91)
                ]
            case .sky:
                return [
                    Color(red: 0.78, green: 0.90, blue: 0.98),
                    Color(red: 0.63, green: 0.80, blue: 0.94)
                ]
            case .mint:
                return [
                    Color(red: 0.80, green: 0.96, blue: 0.82),
                    Color(red: 0.66, green: 0.88, blue: 0.74)
                ]
            case .butter:
                return [
                    Color(red: 1.0, green: 0.95, blue: 0.78),
                    Color(red: 0.98, green: 0.87, blue: 0.60)
                ]
            case .rose:
                return [
                    Color(red: 0.97, green: 0.82, blue: 0.88),
                    Color(red: 0.94, green: 0.70, blue: 0.79)
                ]
            }
        }
    }

    func intersects(region: MKCoordinateRegion) -> Bool {
        guard let first = coordinates.first else { return false }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let regionMinLat = region.center.latitude - region.span.latitudeDelta / 2
        let regionMaxLat = region.center.latitude + region.span.latitudeDelta / 2
        let regionMinLon = region.center.longitude - region.span.longitudeDelta / 2
        let regionMaxLon = region.center.longitude + region.span.longitudeDelta / 2

        let latOverlap = !(maxLat < regionMinLat || minLat > regionMaxLat)
        let lonOverlap = !(maxLon < regionMinLon || minLon > regionMaxLon)

        return latOverlap && lonOverlap
    }
}
