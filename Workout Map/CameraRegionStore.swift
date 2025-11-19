import Foundation
import MapKit

struct CameraRegionStore {
    private let key = "cachedCameraRegion"

    func save(region: MKCoordinateRegion) {
        let dict: [String: Double] = [
            "centerLat": region.center.latitude,
            "centerLon": region.center.longitude,
            "spanLat": region.span.latitudeDelta,
            "spanLon": region.span.longitudeDelta
        ]
        UserDefaults.standard.set(dict, forKey: key)
    }

    func load() -> MKCoordinateRegion? {
        guard let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Double],
              let centerLat = dict["centerLat"],
              let centerLon = dict["centerLon"],
              let spanLat = dict["spanLat"],
              let spanLon = dict["spanLon"] else {
            return nil
        }
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        let span = MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        return MKCoordinateRegion(center: center, span: span)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
