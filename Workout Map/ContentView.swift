//
//  ContentView.swift
//  Workout Map
//
//  Created by Daryl Roberts on 11/18/25.
//

import SwiftUI
import MapKit

struct ContentView: View {
    private let routes = WorkoutDataProvider.sampleRoutes
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            ForEach(routes) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(
                        route.color.gradient.opacity(0.85),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .ignoresSafeArea()
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapPitchToggle()
        }
        .overlay(alignment: .topLeading) {
            RouteLegendView(routes: routes)
                .padding()
        }
        .task {
            guard case .automatic = cameraPosition,
                  let region = routes.combinedRegion() else { return }
            cameraPosition = .region(region)
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

#Preview {
    ContentView()
}
