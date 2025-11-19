//
//  ContentView.swift
//  Workout Map
//
//  Created by Daryl Roberts on 11/18/25.
//

import Combine
import SwiftUI
import MapKit
import UIKit

@MainActor
struct ContentView: View {
    @StateObject private var workoutStore: WorkoutRouteStore
    @StateObject private var mapViewStore: MapViewStore
    @State private var selectedRoutes: [WorkoutRoute] = []
    @State private var isExporting = false
    @State private var exportImage: UIImage?
    @State private var showExportPreview = false
    @State private var exportErrorMessage: String?
    @State private var exportProgress: ExportProgress?
    private let exporter = RouteTileExporter()

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
        .sheet(isPresented: $showExportPreview) {
            if let exportImage {
                ExportPreviewSheet(image: exportImage)
            }
        }
        .alert("Export Failed", isPresented: Binding(get: { exportErrorMessage != nil }, set: { newValue in
            if !newValue {
                exportErrorMessage = nil
            }
        })) {
            Button("OK", role: .cancel) {
                exportErrorMessage = nil
            }
        } message: {
            Text(exportErrorMessage ?? "")
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
        .overlay(alignment: .top) {
            if let exportProgress {
                ExportStatusBanner(progress: exportProgress)
                    .padding(.top, 20)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottomLeading) {
            Button(action: selectVisibleWorkouts) {
                Image(systemName: "rectangle.dashed")
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(.regularMaterial, in: Circle())
            }
            .padding(.leading, 16)
            .padding(.bottom, 0)
        }
        .overlay(alignment: .topLeading) {
            if selectionCount > 0 {
                Label("\(selectionCount) selected", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.leading, 16)
                    .padding(.top, 16)
            }
        }
        .overlay(alignment: .topTrailing) {
            if selectionCount > 0 {
                Button(action: clearSelection) {
                    Label("Clear Selection", systemImage: "xmark.circle")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(.regularMaterial, in: Capsule())
                }
                .padding(.trailing, 16)
                .padding(.top, 16)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if selectionCount > 0 {
                Button(action: exportSelection) {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(width: 48, height: 48)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .frame(width: 48, height: 48)
                    }
                }
                .disabled(isExporting)
                .frame(width: 48, height: 48)
                .background(.regularMaterial, in: Circle())
                .padding(.trailing, 16)
                .padding(.bottom, 0)
            }
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            mapViewStore.updateVisibleRegion(context.region)
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

extension ContentView {
    private var selectionCount: Int {
        selectedRoutes.count
    }

    private func selectVisibleWorkouts() {
        guard let region = mapViewStore.currentVisibleRegion else {
            selectedRoutes = []
            return
        }
        selectedRoutes = workoutStore.routes.filter { $0.intersects(region: region) }
    }

    private func clearSelection() {
        selectedRoutes.removeAll()
    }

    private func exportSelection() {
        guard !selectedRoutes.isEmpty else { return }
        isExporting = true
        withAnimation {
            exportProgress = ExportProgress(downloaded: 0, total: 0)
        }
        Task {
            do {
                let image = try await exporter.render(routes: selectedRoutes) { downloaded, total in
                    await MainActor.run {
                        withAnimation(.spring()) {
                            exportProgress = ExportProgress(downloaded: downloaded, total: total)
                        }
                    }
                }
                await MainActor.run {
                    self.exportImage = image
                    self.isExporting = false
                    withAnimation(.spring()) {
                        self.exportProgress = nil
                    }
                    self.showExportPreview = true
                }
            } catch {
                await MainActor.run {
                    self.isExporting = false
                    withAnimation(.spring()) {
                        self.exportProgress = nil
                    }
                    self.exportErrorMessage = error.localizedDescription
                }
            }
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ExportProgress: Equatable {
    let downloaded: Int
    let total: Int
}

struct ExportStatusBanner: View {
    let progress: ExportProgress

    var body: some View {
        Label("Downloading tiles \(progress.downloaded)/\(max(progress.total, 1))",
              systemImage: "arrow.down.circle")
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(.regularMaterial, in: Capsule())
    }
}

struct ExportPreviewSheet: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
            .navigationTitle("Export Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Share") { showShareSheet = true }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [image])
            }
        }
    }
}

#Preview {
    ContentView(store: .previewStore)
}
