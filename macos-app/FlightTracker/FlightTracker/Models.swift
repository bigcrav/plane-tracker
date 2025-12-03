import Foundation
import Combine
import CoreLocation

struct FlightEntry: Identifiable, Decodable {
    let id = UUID()
    let callsign: String?
    let origin: String?
    let destination: String?
    let distance: Double?
    let direction: String?
    let airline: String?
    let plane: String?
    let timestamp: String?
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum AppConfiguration {
    private static func plist() -> [String: Any]? {
        guard
            let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return plist
    }

    static var serverURL: URL {
        if let urlString = plist()?["ServerURL"] as? String,
           let parsed = URL(string: urlString) {
            return parsed
        }
        return URL(string: "http://127.0.0.1:8080")!
    }

    static var homeLatitude: Double {
        if let stored = UserDefaults.standard.object(forKey: "home_latitude") as? Double { return stored }
        if let value = plist()?["HomeLatitude"] as? Double { return value }
        return 39.266743 // Parkersburg, WV default
    }

    static var homeLongitude: Double {
        if let stored = UserDefaults.standard.object(forKey: "home_longitude") as? Double { return stored }
        if let value = plist()?["HomeLongitude"] as? Double { return value }
        return -81.561516 // Parkersburg, WV default
    }

    static var radiusMiles: Double {
        if let stored = UserDefaults.standard.object(forKey: "radius_miles") as? Double { return stored }
        if let value = plist()?["RadiusMiles"] as? Double { return value }
        return 10.0
    }

    static func persistHome(lat: Double, lon: Double, radius: Double) {
        UserDefaults.standard.set(lat, forKey: "home_latitude")
        UserDefaults.standard.set(lon, forKey: "home_longitude")
        UserDefaults.standard.set(radius, forKey: "radius_miles")
    }
}

final class FlightStore: ObservableObject {
    static let defaultServerURL = AppConfiguration.serverURL

    @Published var closest: [FlightEntry] = []
    @Published var farthest: [FlightEntry] = []
    @Published var history: [FlightEntry] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var serverURL: URL = FlightStore.defaultServerURL
    @Published var homeLatitude: Double = AppConfiguration.homeLatitude
    @Published var homeLongitude: Double = AppConfiguration.homeLongitude
    @Published var radiusMiles: Double = AppConfiguration.radiusMiles

    private var session: URLSession = .shared
    private let radarFetcher = FlightRadarFetcher()

    func load(server: URL? = nil) {
        if let s = server { serverURL = s }
        isLoading = true
        error = nil

        let group = DispatchGroup()

        func fetch(path: String, assign: @escaping ([FlightEntry]) -> Void) {
            group.enter()
            let url = serverURL.appendingPathComponent(path)
            session.dataTask(with: url) { data, _, err in
                defer { group.leave() }
                if let err = err {
                    DispatchQueue.main.async { self.error = err.localizedDescription }
                    return
                }
                guard let data = data else { return }
                do {
                    let items = try JSONDecoder().decode([FlightEntry].self, from: data)
                    DispatchQueue.main.async { assign(items) }
                } catch {
                    DispatchQueue.main.async { self.error = "Decode failed: \(error.localizedDescription)" }
                }
            }.resume()
        }

        // Closest flights fetched directly from FlightRadar24
        group.enter()
        Task.detached {
            let flights = await self.radarFetcher.fetchClosest(
                homeLat: self.homeLatitude,
                homeLon: self.homeLongitude,
                radiusMiles: self.radiusMiles,
                limit: 5
            )
            DispatchQueue.main.async {
                self.closest = flights
                group.leave()
            }
        }

        // Farthest/history still come from the server
        fetch(path: "farthest/json") { self.farthest = $0 }
        fetch(path: "history/json") { self.history = Array($0.reversed()) }

        group.notify(queue: .main) {
            self.isLoading = false
        }
    }

    func updateHome(lat: Double, lon: Double, radius: Double) {
        homeLatitude = lat
        homeLongitude = lon
        radiusMiles = radius
        AppConfiguration.persistHome(lat: lat, lon: lon, radius: radius)
        load()
    }
}

private struct FlightRadarFetcher {
    func fetchClosest(homeLat: Double, homeLon: Double, radiusMiles: Double, limit: Int) async -> [FlightEntry] {
        let deltaLat = max(0.05, radiusMiles / 69.0)
        let lonScale = max(0.2, abs(cos(homeLat.radians)))
        let deltaLon = max(0.05, radiusMiles / (69.0 * lonScale))
        let bounds = "\(homeLat + deltaLat),\(homeLat - deltaLat),\(homeLon - deltaLon),\(homeLon + deltaLon)"
        guard var components = URLComponents(string: "https://data-live.flightradar24.com/zones/fcgi/feed.js") else { return [] }

        components.queryItems = [
            .init(name: "bounds", value: bounds),
            .init(name: "faa", value: "1"),
            .init(name: "satellite", value: "1"),
            .init(name: "mlat", value: "1"),
            .init(name: "flarm", value: "1"),
            .init(name: "adsb", value: "1"),
            .init(name: "gnd", value: "1"),
            .init(name: "air", value: "1"),
            .init(name: "vehicles", value: "0"),
            .init(name: "estimated", value: "1"),
            .init(name: "maxage", value: "14400"),
            .init(name: "gliders", value: "1")
        ]

        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X) SwiftUI-PlaneTracker", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let flights = parseFeed(data: data, homeLat: homeLat, homeLon: homeLon)
            return Array(flights.prefix(limit))
        } catch {
            return []
        }
    }

    private func parseFeed(data: Data, homeLat: Double, homeLon: Double) -> [FlightEntry] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var results: [FlightEntry] = []

        for (key, value) in root {
            // skip non-flight metadata
            if key == "full_count" || key == "version" || key == "stats" { continue }
            guard let arr = value as? [Any], arr.count >= 17 else { continue }

            let lat = arr.value(Double.self, at: 1)
            let lon = arr.value(Double.self, at: 2)
            guard let lat, let lon else { continue }

            let callsign = arr.value(String.self, at: 16) ?? arr.value(String.self, at: 13) ?? arr.value(String.self, at: 11)
            let origin = arr.value(String.self, at: 11) ?? arr.value(String.self, at: 12)
            let destination = arr.value(String.self, at: 12) ?? arr.value(String.self, at: 13)
            let plane = arr.value(String.self, at: 8)
            let airline = arr.value(String.self, at: 13)

            let distance = haversineMiles(lat1: homeLat, lon1: homeLon, lat2: lat, lon2: lon)
            let direction = bearingCardinal(lat1: homeLat, lon1: homeLon, lat2: lat, lon2: lon)

            let entry = FlightEntry(
                callsign: callsign?.trimmingCharacters(in: .whitespacesAndNewlines),
                origin: origin,
                destination: destination,
                distance: distance,
                direction: direction,
                airline: airline,
                plane: plane,
                timestamp: DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short),
                latitude: lat,
                longitude: lon,
                altitude: arr.value(Double.self, at: 4)
            )
            results.append(entry)
        }

        results.sort { ($0.distance ?? .greatestFiniteMagnitude) < ($1.distance ?? .greatestFiniteMagnitude) }
        return results
    }

    private func haversineMiles(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 3958.8
        let dLat = (lat2 - lat1).radians
        let dLon = (lon2 - lon1).radians
        let a = pow(sin(dLat / 2), 2) + cos(lat1.radians) * cos(lat2.radians) * pow(sin(dLon / 2), 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return r * c
    }

    private func bearingCardinal(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> String {
        let lat1r = lat1.radians
        let lat2r = lat2.radians
        let dLon = (lon2 - lon1).radians
        let y = sin(dLon) * cos(lat2r)
        let x = cos(lat1r) * sin(lat2r) - sin(lat1r) * cos(lat2r) * cos(dLon)
        let brng = atan2(y, x).degrees
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let idx = Int((brng + 360 + 22.5).truncatingRemainder(dividingBy: 360) / 45)
        return dirs[idx % 8]
    }
}

private extension Array where Element == Any {
    func value<T>(_ type: T.Type, at index: Int) -> T? {
        guard indices.contains(index) else { return nil }
        if let val = self[index] as? T { return val }
        if let str = self[index] as? String, let converted = Double(str) as? T {
            return converted
        }
        return nil
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        DispatchQueue.main.async {
            self.currentLocation = latest
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
