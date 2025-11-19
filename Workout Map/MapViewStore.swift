//
//  MapViewStore.swift
//  Workout Map
//
//  Created by Codex on 11/18/25.
//

import Combine
import MapKit
import SwiftUI

@MainActor
final class MapViewStore: ObservableObject {
    @Published var cameraPosition: MapCameraPosition

    private var hasCenteredOnLatestRoute = false

    private let workoutStore: WorkoutRouteStore
    private var latestWorkoutState: WorkoutRouteStore.State = .idle
    private var cancellables = Set<AnyCancellable>()

    init(workoutStore: WorkoutRouteStore) {
        self.workoutStore = workoutStore

        cameraPosition = .automatic
        hasCenteredOnLatestRoute = false

        workoutStore.$routes
            .receive(on: RunLoop.main)
            .sink { [weak self] routes in
                self?.handleRoutesUpdate(routes)
            }
            .store(in: &cancellables)

        workoutStore.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)

        if !workoutStore.routes.isEmpty {
            let sorted = workoutStore.routes.sorted { $0.startDate > $1.startDate }
            handleRoutesUpdate(sorted)
        }
    }

    private func handleRoutesUpdate(_ routes: [WorkoutRoute]) {
        guard !routes.isEmpty,
              let latestRoute = routes.first,
              let region = MapViewStore.regionForRoute(latestRoute) else { return }

        setCameraRegion(region)
    }

    private func handleStateChange(_ state: WorkoutRouteStore.State) {
        latestWorkoutState = state
        if case .loaded = state {
            attemptAutoCenterOnLatestRoute()
        }
    }

    private func attemptAutoCenterOnLatestRoute() {
        guard latestWorkoutState == .loaded,
              !hasCenteredOnLatestRoute,
              let latestRoute = workoutStore.routes.sorted(by: { $0.startDate > $1.startDate }).first,
              let region = MapViewStore.regionForRoute(latestRoute) else { return }

        hasCenteredOnLatestRoute = true
        setCameraRegion(region)
    }

    private func setCameraRegion(_ region: MKCoordinateRegion) {
        withAnimation(.easeInOut(duration: 0.8)) {
            cameraPosition = .region(region)
        }
    }
}

private extension MapViewStore {
    static func regionForRoute(_ route: WorkoutRoute, paddingFactor: Double = 0.15) -> MKCoordinateRegion? {
        let coordinates = route.coordinates
        guard let first = coordinates.first else { return nil }

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

        let latDelta = max((maxLat - minLat) * (1 + paddingFactor), 0.1)
        let lonDelta = max((maxLon - minLon) * (1 + paddingFactor), 0.1)

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
}
