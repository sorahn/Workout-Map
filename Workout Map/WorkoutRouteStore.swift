//
//  WorkoutRouteStore.swift
//  Workout Map
//
//  Created by Codex on 11/18/25.
//

import Combine
import Foundation
import HealthKit
import MapKit
import SwiftUI

@MainActor
final class WorkoutRouteStore: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingAccess
        case loading
        case loaded
        case empty
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle),
                 (.requestingAccess, .requestingAccess),
                 (.loading, .loading),
                 (.loaded, .loaded),
                 (.empty, .empty):
                return true
            case let (.error(a), .error(b)):
                return a == b
            default:
                return false
            }
        }
    }

    struct LoadingProgress: Equatable {
        let total: Int
        let loaded: Int

        var fractionCompleted: Double {
            guard total > 0 else { return 0 }
            return Double(loaded) / Double(total)
        }
    }

    @Published private(set) var routes: [WorkoutRoute] = []
    @Published private(set) var state: State = .idle
    @Published private(set) var loadingProgress: LoadingProgress?

    private let healthStore = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()
    private let routeType = HKSeriesType.workoutRoute()
    private let cache: WorkoutRouteCache
    private let colorPalette: [WorkoutRoute.RouteColor] = [
        .sunrise, .peach, .seafoam, .lavender, .sky, .mint, .butter, .rose
    ]
    private var cachedCameraRegion: MKCoordinateRegion?
    private var pendingCameraSaveTask: Task<Void, Never>?
    private var hasAttemptedInitialLoad = false
    private var hasRequestedHealthAccess = false

    private let maxWorkoutsToFetch = HKObjectQueryNoLimit

    init(cache: WorkoutRouteCache = WorkoutRouteCache()) {
        self.cache = cache
        let payload = cache.load()
        let cachedRoutes = payload.routes
        self.cachedCameraRegion = payload.cameraRegion
        if !cachedRoutes.isEmpty {
            self.routes = cachedRoutes
            self.state = .loaded
        }
    }

    var initialCameraRegion: MKCoordinateRegion? {
        cachedCameraRegion
    }

    func refreshWorkoutsIfNeeded() async {
        guard !hasAttemptedInitialLoad else { return }
        hasAttemptedInitialLoad = true
        await refreshWorkouts()
    }

    func refreshWorkouts() async {
        loadingProgress = nil

        do {
            try await loadWorkouts()
        } catch let error as WorkoutRouteStoreError {
            state = .error(error.errorDescription ?? "Something went wrong.")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func loadWorkouts() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw WorkoutRouteStoreError.healthDataUnavailable
        }

        if !hasRequestedHealthAccess {
            state = .requestingAccess
            try await healthStore.requestAuthorization(toShare: [], read: [workoutType, routeType])
            hasRequestedHealthAccess = true
        }

        state = .loading
        loadingProgress = nil

        do {
            let workouts = try await fetchAllWorkouts(limit: maxWorkoutsToFetch)
            if !workouts.isEmpty {
                loadingProgress = LoadingProgress(total: workouts.count, loaded: 0)
            }

            var refreshedRoutes: [WorkoutRoute] = []

            for (index, workout) in workouts.enumerated() {
                if let route = try await buildRoute(
                    for: workout,
                    color: colorForRoute(at: refreshedRoutes.count)
                ) {
                    refreshedRoutes.append(route)
                    self.routes = refreshedRoutes
                } else if refreshedRoutes.isEmpty {
                    self.routes = []
                }

                loadingProgress = LoadingProgress(
                    total: workouts.count,
                    loaded: index + 1
                )
            }

            loadingProgress = nil
            self.routes = refreshedRoutes
            state = refreshedRoutes.isEmpty ? .empty : .loaded
            cache.save(routes: refreshedRoutes, cameraRegion: cachedCameraRegion)
        } catch let error as HKError where error.code == .errorAuthorizationDenied {
            loadingProgress = nil
            throw WorkoutRouteStoreError.authorizationDenied
        } catch {
            loadingProgress = nil
            throw error
        }
    }

    private func fetchAllWorkouts(limit: Int) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }

            healthStore.execute(query)
        }
    }

    private func colorForRoute(at index: Int) -> WorkoutRoute.RouteColor {
        guard !colorPalette.isEmpty else { return .sunrise }
        return colorPalette[index % colorPalette.count]
    }

    private func buildRoute(for workout: HKWorkout, color: WorkoutRoute.RouteColor) async throws -> WorkoutRoute? {
        let routeSamples = try await fetchRouteSamples(for: workout)
        guard !routeSamples.isEmpty else { return nil }

        var allCoordinates: [CLLocationCoordinate2D] = []
        for routeSample in routeSamples {
            let coordinates = try await readCoordinates(for: routeSample)
            allCoordinates.append(contentsOf: coordinates)
        }

        guard allCoordinates.count > 1 else { return nil }

        let meters = workout.totalDistance?.doubleValue(for: HKUnit.meter()) ?? Self.estimateDistance(from: allCoordinates)
        let kilometers = meters / 1000

        return WorkoutRoute(
            name: workout.workoutActivityType.displayName,
            distanceInKilometers: kilometers,
            coordinates: allCoordinates,
            color: color
        )
    }
    func persistCameraRegion(_ region: MKCoordinateRegion) {
        cachedCameraRegion = region
        pendingCameraSaveTask?.cancel()
        let currentRoutes = routes
        pendingCameraSaveTask = Task { [cache] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            cache.save(routes: currentRoutes, cameraRegion: region)
        }
    }

    private func fetchRouteSamples(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let routes = samples as? [HKWorkoutRoute] else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: routes)
            }

            healthStore.execute(query)
        }
    }

    private func readCoordinates(for route: HKWorkoutRoute) async throws -> [CLLocationCoordinate2D] {
        try await withCheckedThrowingContinuation { continuation in
            var collectedCoordinates: [CLLocationCoordinate2D] = []
            var hasCompleted = false

            let routeQuery = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if hasCompleted { return }

                if let error {
                    hasCompleted = true
                    continuation.resume(throwing: error)
                    return
                }

                if let locations {
                    collectedCoordinates.append(contentsOf: locations.map(\.coordinate))
                }

                if done {
                    hasCompleted = true
                    continuation.resume(returning: collectedCoordinates)
                }
            }

            healthStore.execute(routeQuery)
        }
    }

    private static func estimateDistance(from coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }

        var distance: CLLocationDistance = 0
        for index in 1..<coordinates.count {
            let start = CLLocation(latitude: coordinates[index - 1].latitude, longitude: coordinates[index - 1].longitude)
            let end = CLLocation(latitude: coordinates[index].latitude, longitude: coordinates[index].longitude)
            distance += end.distance(from: start)
        }

        return distance
    }
}

private enum WorkoutRouteStoreError: LocalizedError {
    case healthDataUnavailable
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Health data isn't available on this device."
        case .authorizationDenied:
            return "Workout access hasn't been granted. You can update this inside the Health app."
        }
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Ride"
        case .hiking: return "Hike"
        case .swimming: return "Swim"
        case .rowing: return "Row"
        case .paddleSports: return "Paddle"
        case .wheelchairRunPace: return "Wheelchair Run"
        case .wheelchairWalkPace: return "Wheelchair Walk"
        case .crossCountrySkiing: return "XC Ski"
        default:
            return "Workout"
        }
    }
}

#if DEBUG
extension WorkoutRouteStore {
    static var previewStore: WorkoutRouteStore {
        let store = WorkoutRouteStore()
        store.routes = WorkoutDataProvider.sampleRoutes
        store.state = .loaded
        store.hasAttemptedInitialLoad = true
        return store
    }
}
#endif
