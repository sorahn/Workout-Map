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
    @State private var cameraPosition: MapCameraPosition = .automatic

    init(store: WorkoutRouteStore = WorkoutRouteStore()) {
        _workoutStore = StateObject(wrappedValue: store)
    }

    var body: some View {
        ZStack(alignment: .center) {
            mapLayer
            stateOverlay
        }
        .task {
            await workoutStore.refreshWorkoutsIfNeeded()
        }
        .onReceive(workoutStore.$routes) { newRoutes in
            guard !newRoutes.isEmpty,
                  let region = newRoutes.combinedRegion() else { return }
            cameraPosition = .region(region)
        }
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            ForEach(workoutStore.routes) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(
                        route.color.gradient.opacity(0.85),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .ignoresSafeArea()
        .mapStyle(.standard(elevation: .realistic))
        .overlay(alignment: .topLeading) {
            if !workoutStore.routes.isEmpty {
                RouteLegendView(routes: workoutStore.routes)
                    .padding()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            MapControlsPanel()
                .padding()
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch workoutStore.state {
        case .requestingAccess:
            StatusOverlayView(
                title: "Allow Health Access",
                message: "Approve the HealthKit prompt so we can pull your workouts.",
                showProgress: true
            )
        case .loading:
            StatusOverlayView(
                title: "Loading workouts...",
                message: "Pulling your recent Health workouts and routes.",
                showProgress: true
            )
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

private struct RouteLegendView: View {
    let routes: [WorkoutRoute]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Workout Routes")
                    .font(.headline)
                Text("\(routes.count) workouts • \(WorkoutRoute.formatDistance(routes.totalDistance)) total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(routes) { route in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(route.color.gradient)
                        .frame(width: 16, height: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(route.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(route.formattedDistance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
    }
}

private struct MapControlsPanel: View {
    var body: some View {
        VStack(spacing: 12) {
            MapUserLocationButton()
            MapCompass()
            MapPitchToggle()
        }
        .buttonBorderShape(.circle)
        .controlSize(.large)
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

#Preview {
    ContentView(store: .previewStore)
}
