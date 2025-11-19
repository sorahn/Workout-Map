import Foundation
import MapKit
import UIKit

final class RouteTileExporter {
    enum ExportError: LocalizedError {
        case noRoutes
        case tileDownloadFailed

        var errorDescription: String? {
            switch self {
            case .noRoutes:
                return "No routes available to export."
            case .tileDownloadFailed:
                return "We couldn't download map tiles. Check your connection and try again."
            }
        }
    }

    private let zoomLevel = 15
    private let tileSize: CGFloat = 256
    private let paddingTiles = 1
    private let tileBaseURL = URL(string: "https://tile.openstreetmap.org")!

    func render(routes: [WorkoutRoute], progress: ((Int, Int) -> Void)? = nil) async throws -> UIImage {
        guard let bounds = routes.combinedBoundingBox() else {
            throw ExportError.noRoutes
        }

        let minMaxTiles = tileBounds(for: bounds)
        let tiles = minMaxTiles.tiles

        await MainActor.run {
            progress?(0, tiles.count)
        }

        let tileImages = try await fetchTiles(tiles: tiles, progress: progress)
        return drawImage(with: tileImages,
                         tiles: tiles,
                         routes: routes,
                         minTileX: minMaxTiles.minX,
                         minTileY: minMaxTiles.minY)
    }

    private func fetchTiles(tiles: [TileCoordinate], progress: ((Int, Int) -> Void)?) async throws -> [TileCoordinate: UIImage] {
        let total = tiles.count
        return try await withThrowingTaskGroup(of: (TileCoordinate, UIImage).self) { group in
            for tile in tiles {
                group.addTask { [zoomLevel, tileBaseURL] in
                    let url = tileBaseURL
                        .appendingPathComponent("\(zoomLevel)")
                        .appendingPathComponent("\(tile.x)")
                        .appendingPathComponent("\(tile.y).png")
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let image = UIImage(data: data) else {
                        throw ExportError.tileDownloadFailed
                    }
                    return (tile, image)
                }
            }
            var images: [TileCoordinate: UIImage] = [:]
            var downloaded = 0
            for try await (tile, image) in group {
                images[tile] = image
                downloaded += 1
                if let progress {
                    await MainActor.run {
                        progress(downloaded, total)
                    }
                }
            }
            return images
        }
    }

    private func drawImage(with tileImages: [TileCoordinate: UIImage],
                           tiles: [TileCoordinate],
                           routes: [WorkoutRoute],
                           minTileX: Int,
                           minTileY: Int) -> UIImage {
        let maxTileX = tiles.map(\.x).max() ?? minTileX
        let maxTileY = tiles.map(\.y).max() ?? minTileY
        let width = CGFloat(maxTileX - minTileX + 1) * tileSize
        let height = CGFloat(maxTileY - minTileY + 1) * tileSize
        let originX = Double(minTileX) * Double(tileSize)
        let originY = Double(minTileY) * Double(tileSize)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { _ in
            for tile in tiles {
                let rect = CGRect(x: CGFloat(tile.x - minTileX) * tileSize,
                                  y: CGFloat(tile.y - minTileY) * tileSize,
                                  width: tileSize,
                                  height: tileSize)
                if let image = tileImages[tile] {
                    image.draw(in: rect, blendMode: .normal, alpha: 0.5)
                } else {
                    UIColor.systemGray6.setFill()
                    UIBezierPath(rect: rect).fill()
                }
            }

            let strokeColor = UIColor(red: 0.86, green: 0.18, blue: 0.24, alpha: 0.95)
            strokeColor.setStroke()

            for route in routes {
                guard route.coordinates.count > 1 else { continue }
                let path = UIBezierPath()
                path.lineWidth = 1
                path.lineJoinStyle = .round
                path.lineCapStyle = .round

                for (index, coordinate) in route.coordinates.enumerated() {
                    let point = pixelPoint(for: coordinate, zoom: zoomLevel)
                    let translated = CGPoint(x: point.x - originX, y: point.y - originY)
                    if index == 0 {
                        path.move(to: translated)
                    } else {
                        path.addLine(to: translated)
                    }
                }

                path.stroke()
            }
        }
    }

    private func tileBounds(for bounds: RouteBoundingBox) -> (tiles: [TileCoordinate], minX: Int, minY: Int) {
        let maxIndex = (1 << zoomLevel) - 1

        let minTileX = max(0, Int(floor(tileX(for: bounds.minLongitude))) - paddingTiles)
        let maxTileX = min(maxIndex, Int(floor(tileX(for: bounds.maxLongitude))) + paddingTiles)

        let northTileY = Int(floor(tileY(for: bounds.maxLatitude))) - paddingTiles
        let southTileY = Int(floor(tileY(for: bounds.minLatitude))) + paddingTiles
        let minTileY = max(0, northTileY)
        let maxTileY = min(maxIndex, southTileY)

        var tiles: [TileCoordinate] = []
        for x in minTileX...maxTileX {
            for y in minTileY...maxTileY {
                tiles.append(TileCoordinate(x: x, y: y))
            }
        }

        return (tiles, minTileX, minTileY)
    }

    private func tileX(for longitude: Double) -> Double {
        ((longitude + 180.0) / 360.0) * pow(2.0, Double(zoomLevel))
    }

    private func tileY(for latitude: Double) -> Double {
        let latRad = latitude * .pi / 180.0
        let n = tan(.pi / 4 + latRad / 2)
        return (1 - log(n) / .pi) / 2 * pow(2.0, Double(zoomLevel))
    }

    private func pixelPoint(for coordinate: CLLocationCoordinate2D, zoom: Int) -> (x: Double, y: Double) {
        let scale = pow(2.0, Double(zoom))
        let x = ((coordinate.longitude + 180.0) / 360.0) * scale * Double(tileSize)
        let latRad = coordinate.latitude * .pi / 180.0
        let y = (1 - log(tan(latRad) + 1 / cos(latRad)) / .pi) / 2 * scale * Double(tileSize)
        return (x, y)
    }

    private struct TileCoordinate: Hashable {
        let x: Int
        let y: Int
    }
}
