import WidgetKit
import SwiftUI
import Foundation
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

struct FlightSnapshot: TimelineEntry {
    let date: Date
    let closest: [FlightEntry]
    let home: CLLocationCoordinate2D
    let radiusMiles: Double
}

struct Provider: TimelineProvider {
    private let fetcher = WidgetFlightRadarFetcher()
    private let defaults = WidgetDefaults()

    func placeholder(in context: Context) -> FlightSnapshot {
        FlightSnapshot(date: Date(), closest: defaults.sampleFlights, home: defaults.homeCoordinate, radiusMiles: defaults.radiusMiles)
    }

    func getSnapshot(in context: Context, completion: @escaping (FlightSnapshot) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlightSnapshot>) -> Void) {
        Task {
            let flights = await fetcher.fetchClosest(
                homeLat: defaults.homeLatitude,
                homeLon: defaults.homeLongitude,
                radiusMiles: defaults.radiusMiles,
                limit: 3
            )
            let entry = FlightSnapshot(date: Date(), closest: flights, home: defaults.homeCoordinate, radiusMiles: defaults.radiusMiles)
            let next = Date().addingTimeInterval(60 * 10)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct PlaneTrackerWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last flight within \(Int(entry.radiusMiles)) mi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "Lat %.3f, Lon %.3f", entry.home.latitude, entry.home.longitude))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "airplane.circle.fill")
                    .foregroundStyle(.blue)
            }
            if let first = entry.closest.first {
                HighlightFlightRow(flight: first)
            } else {
                Text("No aircraft in range")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            if entry.closest.count > 1 {
                Divider()
                Text("Recent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(entry.closest.dropFirst().prefix(1))) { flight in
                    FlightRow(flight: flight)
                }
            }
        }
        .padding(12)
    }
}

struct FlightRow: View {
    let flight: FlightEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(flight.callsign ?? "UNKNOWN").font(.subheadline).fontWeight(.semibold)
            Text("\(flight.origin ?? "UNK") → \(flight.destination ?? "UNK")")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                if let d = flight.distance {
                    Text(String(format: "%.0f mi", d))
                }
                Text(flight.direction ?? "")
                Spacer()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

struct HighlightFlightRow: View {
    let flight: FlightEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(flight.callsign ?? "UNKNOWN")
                    .font(.headline.weight(.semibold))
                Spacer()
                if let ts = flight.timestamp {
                    Text(ts)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text("\(flight.origin ?? "UNK") → \(flight.destination ?? "UNK")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                if let distance = flight.distance {
                    Label(String(format: "%.1f mi", distance), systemImage: "mappin")
                }
                if let dir = flight.direction {
                    Label(dir, systemImage: "location.north")
                }
                if let altitude = flight.altitude {
                    Label(String(format: "%.0f ft", altitude), systemImage: "chevron.up")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

@main
struct PlaneTrackerWidget: Widget {
    let kind: String = "PlaneTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            PlaneTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Plane Tracker")
        .description("Shows the most recent aircraft in a 10 mile radius.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct WidgetDefaults {
    private let storage = UserDefaults(suiteName: "group.plane.tracker") ?? .standard

    var homeLatitude: Double {
        if let stored = storage.object(forKey: "home_latitude") as? Double { return stored }
        return 39.266743
    }

    var homeLongitude: Double {
        if let stored = storage.object(forKey: "home_longitude") as? Double { return stored }
        return -81.561516
    }

    var radiusMiles: Double {
        if let stored = storage.object(forKey: "radius_miles") as? Double { return stored }
        return 10
    }

    var homeCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: homeLatitude, longitude: homeLongitude)
    }

    var sampleFlights: [FlightEntry] {
        [
            FlightEntry(callsign: "SAMP123", origin: "ORD", destination: "LAX", distance: 8.2, direction: "W", airline: "Sample Air", plane: "A320", timestamp: "Now", latitude: homeLatitude + 0.02, longitude: homeLongitude + 0.01, altitude: 32000),
            FlightEntry(callsign: "SAMP456", origin: "JFK", destination: "SFO", distance: 9.5, direction: "SW", airline: "Sample Air", plane: "B738", timestamp: "1m ago", latitude: homeLatitude - 0.01, longitude: homeLongitude - 0.02, altitude: 28000)
        ]
    }
}

private struct WidgetFlightRadarFetcher {
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
