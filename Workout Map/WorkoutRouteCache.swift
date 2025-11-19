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

        init(from coordinate: CLLocationCoordinate2D) {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
        }
    }

    let id: UUID
    let name: String
    let distanceInKilometers: Double
    let coordinates: [Coordinate]
    let color: WorkoutRoute.RouteColor

    init(route: WorkoutRoute) {
        self.id = route.id
        self.name = route.name
        self.distanceInKilometers = route.distanceInKilometers
        self.coordinates = route.coordinates.map(Coordinate.init)
        self.color = route.routeColor
    }

    func makeRoute() -> WorkoutRoute {
        WorkoutRoute(
            id: id,
            name: name,
            distanceInKilometers: distanceInKilometers,
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
        DispatchQueue.global(qos: .utility).async { [encoder, fileURL] in
            do {
                let document = WorkoutRouteCacheDocument(
                    routes: routes.map { WorkoutRouteCacheDTO(route: $0) },
                    cameraRegion: cameraRegion.map { CameraRegion(region: $0) }
                )
                let data = try encoder.encode(document)
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                // Silently ignore cache write errors.
            }

            if let completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
}
