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

    private(set) var hasManuallyAdjustedCamera = false
    private var shouldFitRoutesOnUpdate: Bool
    private var hasCenteredOnUser = false
    private var isProgrammaticCameraChange = false

    private let workoutStore: WorkoutRouteStore
    private let locationProvider = LocationProvider()
    private var latestWorkoutState: WorkoutRouteStore.State = .idle
    private var cancellables = Set<AnyCancellable>()

    init(workoutStore: WorkoutRouteStore) {
        self.workoutStore = workoutStore

        if let cachedRegion = workoutStore.initialCameraRegion {
            cameraPosition = .region(cachedRegion)
            shouldFitRoutesOnUpdate = false
            isProgrammaticCameraChange = true
        } else {
            cameraPosition = .automatic
            shouldFitRoutesOnUpdate = true
            isProgrammaticCameraChange = true
        }

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

        locationProvider.$currentLocation
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.attemptAutoCenterOnUser()
            }
            .store(in: &cancellables)
    }

    func handleCameraChange(region: MKCoordinateRegion?) {
        guard let region else { return }

        if isProgrammaticCameraChange {
            isProgrammaticCameraChange = false
        } else {
            hasManuallyAdjustedCamera = true
        }

        workoutStore.persistCameraRegion(region)
    }

    private func handleRoutesUpdate(_ routes: [WorkoutRoute]) {
        guard !routes.isEmpty,
              shouldFitRoutesOnUpdate,
              !hasManuallyAdjustedCamera,
              let region = routes.combinedRegion() else { return }

        setCameraRegion(region)
        shouldFitRoutesOnUpdate = false
    }

    private func handleStateChange(_ state: WorkoutRouteStore.State) {
        latestWorkoutState = state
        if case .loaded = state {
            attemptAutoCenterOnUser()
        }
    }

    private func attemptAutoCenterOnUser() {
        guard latestWorkoutState == .loaded,
              !hasManuallyAdjustedCamera,
              !hasCenteredOnUser,
              let coordinate = locationProvider.currentLocation?.coordinate else { return }

        hasCenteredOnUser = true
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        setCameraRegion(region)
    }

    private func setCameraRegion(_ region: MKCoordinateRegion) {
        isProgrammaticCameraChange = true
        cameraPosition = .region(region)
        workoutStore.persistCameraRegion(region)
    }
}
