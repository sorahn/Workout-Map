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

final class WorkoutRouteCache {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.fileURL = cachesDirectory.appendingPathComponent("workout-routes-cache.json")
    }

    func loadRoutes() -> [WorkoutRoute] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        do {
            let dtos = try decoder.decode([WorkoutRouteCacheDTO].self, from: data)
            return dtos.map { $0.makeRoute() }
        } catch {
            return []
        }
    }

    func saveRoutes(_ routes: [WorkoutRoute]) {
        do {
            let dtos = routes.map { WorkoutRouteCacheDTO(route: $0) }
            let data = try encoder.encode(dtos)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Silently ignore cache write errors.
        }
    }
}
