//
//  WorkoutRouteCache.swift
//  Workout Map
//
//  Created by Codex on 11/18/25.
//

import Foundation
import MapKit

struct WorkoutRouteCacheDTO: Codable {
    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double

        var clCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    let id: UUID
    let workoutIdentifier: UUID?
    let name: String
    let distanceInKilometers: Double
    let startDate: Date?
    let coordinates: [Coordinate]
    let color: WorkoutRoute.RouteColor

    init(route: WorkoutRoute) {
        self.id = route.id
        self.workoutIdentifier = route.workoutIdentifier
        self.name = route.name
        self.distanceInKilometers = route.distanceInKilometers
        self.startDate = route.startDate
        self.coordinates = route.coordinates.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
        self.color = route.routeColor
    }

    func makeRoute() -> WorkoutRoute {
        WorkoutRoute(
            id: id,
            workoutIdentifier: workoutIdentifier,
            name: name,
            distanceInKilometers: distanceInKilometers,
            startDate: startDate ?? Date(),
            coordinates: coordinates.map(\.clCoordinate),
            color: color
        )
    }
}

private struct WorkoutRouteCacheDocument: Codable {
    var routes: [WorkoutRouteCacheDTO]
    var cameraRegion: CameraRegion?
}

private struct CameraRegion: Codable {
    let centerLatitude: Double
    let centerLongitude: Double
    let spanLatitudeDelta: Double
    let spanLongitudeDelta: Double

    init(centerLatitude: Double, centerLongitude: Double, spanLatitudeDelta: Double, spanLongitudeDelta: Double) {
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.spanLatitudeDelta = spanLatitudeDelta
        self.spanLongitudeDelta = spanLongitudeDelta
    }

    init(region: MKCoordinateRegion) {
        centerLatitude = region.center.latitude
        centerLongitude = region.center.longitude
        spanLatitudeDelta = region.span.latitudeDelta
        spanLongitudeDelta = region.span.longitudeDelta
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude),
            span: MKCoordinateSpan(
                latitudeDelta: spanLatitudeDelta,
                longitudeDelta: spanLongitudeDelta
            )
        )
    }
}

struct WorkoutRouteCachePayload {
    let routes: [WorkoutRoute]
    let cameraRegion: MKCoordinateRegion?
}

final class WorkoutRouteCache {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.fileURL = cachesDirectory.appendingPathComponent("workout-routes-cache.json")
    }

    func load() -> WorkoutRouteCachePayload {
        guard let data = try? Data(contentsOf: fileURL) else {
            return WorkoutRouteCachePayload(routes: [], cameraRegion: nil)
        }

        if let document = try? decoder.decode(WorkoutRouteCacheDocument.self, from: data) {
            let routes = document.routes.map { $0.makeRoute() }
            return WorkoutRouteCachePayload(
                routes: routes,
                cameraRegion: document.cameraRegion?.region
            )
        } else if let legacyRoutes = try? decoder.decode([WorkoutRouteCacheDTO].self, from: data) {
            return WorkoutRouteCachePayload(
                routes: legacyRoutes.map { $0.makeRoute() },
                cameraRegion: nil
            )
        } else {
            return WorkoutRouteCachePayload(routes: [], cameraRegion: nil)
        }
    }

    func save(routes: [WorkoutRoute], cameraRegion: MKCoordinateRegion?, completion: (() -> Void)? = nil) {
        let fileURL = self.fileURL
        let encoder = self.encoder
        let storedRegion = cameraRegion.map {
            CameraRegion(
                centerLatitude: $0.center.latitude,
                centerLongitude: $0.center.longitude,
                spanLatitudeDelta: $0.span.latitudeDelta,
                spanLongitudeDelta: $0.span.longitudeDelta
            )
        }

        Task.detached(priority: .utility) {
            let document = WorkoutRouteCacheDocument(
                routes: routes.map { WorkoutRouteCacheDTO(route: $0) },
                cameraRegion: storedRegion
            )
            do {
                let data = try encoder.encode(document)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                // Silently ignore cache write errors.
            }

            if let completion {
                await MainActor.run {
                    completion()
                }
            }
        }
    }
}
