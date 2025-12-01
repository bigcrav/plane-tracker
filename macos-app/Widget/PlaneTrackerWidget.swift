import WidgetKit
import SwiftUI

struct FlightSnapshot: TimelineEntry {
    let date: Date
    let closest: [FlightEntry]
    let farthest: [FlightEntry]
    let server: URL
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> FlightSnapshot {
        FlightSnapshot(date: Date(), closest: sampleFlights(), farthest: sampleFlights(), server: URL(string: "http://localhost:8080")!)
    }

    func getSnapshot(in context: Context, completion: @escaping (FlightSnapshot) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlightSnapshot>) -> Void) {
        Task {
            let server = URL(string: UserDefaults.standard.string(forKey: "server_url") ?? "http://localhost:8080")!
            let closest = await fetch(path: "closest/json", server: server)
            let farthest = await fetch(path: "farthest/json", server: server)
            let entry = FlightSnapshot(date: Date(), closest: closest, farthest: farthest, server: server)
            let next = Date().addingTimeInterval(60 * 5)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetch(path: String, server: URL) async -> [FlightEntry] {
        let url = server.appendingPathComponent(path)
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let items = try JSONDecoder().decode([FlightEntry].self, from: data)
            return items
        } catch {
            return []
        }
    }

    private func sampleFlights() -> [FlightEntry] {
        [
            FlightEntry(callsign: "SAMP123", origin: "ORD", destination: "LAX", distance: 1234, direction: "W", airline: "Sample Air", plane: "A320"),
            FlightEntry(callsign: "SAMP456", origin: "JFK", destination: "SFO", distance: 2450, direction: "W", airline: "Sample Air", plane: "B738")
        ]
    }
}

struct PlaneTrackerWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Closest").font(.caption).foregroundColor(.secondary)
            ForEach(entry.closest.prefix(2)) { flight in
                FlightRow(flight: flight)
            }
            Divider()
            Text("Farthest").font(.caption).foregroundColor(.secondary)
            ForEach(entry.farthest.prefix(2)) { flight in
                FlightRow(flight: flight)
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
                .foregroundColor(.secondary)
            HStack {
                if let d = flight.distance {
                    Text(String(format: "%.0f", d))
                }
                Text(flight.direction ?? "")
                Spacer()
            }
            .font(.caption2)
            .foregroundColor(.secondary)
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
        .description("Shows closest and farthest flights.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
