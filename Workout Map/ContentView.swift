//
//  ContentView.swift
//  Workout Map
//
//  Created by Daryl Roberts on 11/18/25.
//

import Combine
import SwiftUI
import MapKit

@MainActor
struct ContentView: View {
    @StateObject private var workoutStore: WorkoutRouteStore
    @StateObject private var mapViewStore: MapViewStore

    init() {
        let store = WorkoutRouteStore()
        _workoutStore = StateObject(wrappedValue: store)
        _mapViewStore = StateObject(wrappedValue: MapViewStore(workoutStore: store))
    }

    init(store: WorkoutRouteStore) {
        _workoutStore = StateObject(wrappedValue: store)
        _mapViewStore = StateObject(wrappedValue: MapViewStore(workoutStore: store))
    }

var body: some View {
    ZStack(alignment: .center) {
        mapLayer
        stateOverlay
    }
    .task {
        await workoutStore.refreshWorkoutsIfNeeded()
    }
}

    private var mapLayer: some View {
        Map(position: $mapViewStore.cameraPosition, interactionModes: .all) {
            ForEach(workoutStore.routes) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(
                        route.strokeStyle,
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .ignoresSafeArea()
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .overlay(alignment: .top) {
            if let progress = workoutStore.loadingProgress {
                LoadingStatusBar(progress: progress)
                    .padding(.horizontal)
                    .padding(.top)
            }
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch workoutStore.state {
        case .requestingAccess where workoutStore.routes.isEmpty:
            StatusOverlayView(
                title: "Allow Health Access",
                message: "Approve the HealthKit prompt so we can pull your workouts.",
                showProgress: true
            )
        case .requestingAccess:
            EmptyView()
        case .loading:
            EmptyView()
        case .empty:
            StatusOverlayView(
                title: "No workout routes yet",
                message: "Record an outdoor workout with route tracking (Run, Walk, Ride) and refresh.",
                actionTitle: "Refresh"
            ) {
                Task { await workoutStore.refreshWorkouts() }
            }
        case .error(let message):
            StatusOverlayView(
                title: "We couldn't load workouts",
                message: message,
                actionTitle: "Try Again"
            ) {
                Task { await workoutStore.refreshWorkouts() }
            }
        default:
            EmptyView()
        }
    }
}

private struct StatusOverlayView: View {
    let title: String
    let message: String
    var showProgress: Bool = false
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            if showProgress {
                ProgressView()
                    .progressViewStyle(.circular)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding()
    }
}

private struct LoadingStatusBar: View {
    let progress: WorkoutRouteStore.LoadingProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loading workouts")
                        .font(.headline)
                    Text("\(progress.loaded) of \(progress.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ProgressView(
                value: Double(progress.loaded),
                total: Double(max(progress.total, 1))
            )
            .progressViewStyle(.linear)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}

#Preview {
    ContentView(store: .previewStore)
}
