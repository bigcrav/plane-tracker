import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: FlightStore
    @State private var latText: String = ""
    @State private var lonText: String = ""
    @State private var radiusText: String = ""

    var body: some View {
        ZStack {
            background
            VStack(spacing: 24) {
                header
                HomeSettings(
                    latText: $latText,
                    lonText: $lonText,
                    radiusText: $radiusText,
                    onApply: applyHomeSettings
                )
                HStack(spacing: 18) {
                    FlightList(title: "Closest flights", flights: store.closest)
                    FlightList(title: "Farthest flights", flights: store.farthest)
                }
                HistoryList(entries: store.history)
            }
            .padding(24)
        }
        .task {
            latText = String(format: "%.6f", store.homeLatitude)
            lonText = String(format: "%.6f", store.homeLongitude)
            radiusText = String(format: "%.1f", store.radiusMiles)
            store.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plane Tracker")
                        .font(.title2.weight(.semibold))
                    Label("Server configured via Config.plist", systemImage: "lock.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    store.load()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.15)))
                }
                if store.isLoading {
                    ProgressView().scaleEffect(0.9)
                }
            }
            if let error = store.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.1)))
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.5), .mint.opacity(0.4)],
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Circle()
                .fill(.white.opacity(0.12))
                .blur(radius: 80)
                .offset(x: -180, y: -320)
            Circle()
                .fill(.white.opacity(0.08))
                .blur(radius: 90)
                .offset(x: 220, y: 240)
        }
    }

    private func applyHomeSettings() {
        guard
            let lat = Double(latText),
            let lon = Double(lonText),
            let radius = Double(radiusText),
            radius > 0
        else {
            store.error = "Enter valid lat/lon and radius."
            return
        }
        store.error = nil
        store.updateHome(lat: lat, lon: lon, radius: radius)
    }
}

struct GlassPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.08)))
    }
}

struct HomeSettings: View {
    @Binding var latText: String
    @Binding var lonText: String
    @Binding var radiusText: String
    let onApply: () -> Void

    var body: some View {
        GlassPanel(title: "Home settings", subtitle: "Defines the bounding box for closest flights") {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    TextField("Latitude", text: $latText)
                        .textFieldStyle(.roundedBorder)
                    TextField("Longitude", text: $lonText)
                        .textFieldStyle(.roundedBorder)
                    TextField("Radius (miles)", text: $radiusText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 130)
                }
                HStack {
                    Text("Defaults to Parkersburg, WV with 10 mi radius.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        onApply()
                    } label: {
                        Label("Apply & Refresh", systemImage: "location.fill")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.1)))
                    }
                }
            }
        }
    }
}

struct FlightList: View {
    let title: String
    let flights: [FlightEntry]

    var body: some View {
        GlassPanel(title: title, subtitle: nil) {
            if flights.isEmpty {
                Text("No data yet").foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(flights) { flight in
                            FlightRowView(flight: flight, showTimestamp: false)
                        }
                    }
                }
            }
        }
    }
}

struct HistoryList: View {
    let entries: [FlightEntry]

    var body: some View {
        GlassPanel(title: "Recent history", subtitle: "Latest processed flights") {
            if entries.isEmpty {
                Text("No history yet").foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(entries) { entry in
                            FlightRowView(flight: entry, showTimestamp: true)
                        }
                    }
                }
            }
        }
    }
}

struct FlightRowView: View {
    let flight: FlightEntry
    let showTimestamp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(flight.callsign ?? "UNKNOWN")
                    .fontWeight(.semibold)
                Spacer()
                if showTimestamp, let ts = flight.timestamp {
                    Text(ts).foregroundColor(.secondary)
                }
            }
            Text("\(flight.origin ?? "UNK") → \(flight.destination ?? "UNK")")
                .foregroundColor(.secondary)
            HStack(spacing: 10) {
                if let d = flight.distance {
                    Text(String(format: "%.1f", d))
                }
                Text(flight.direction ?? "")
                Spacer()
                Text(flight.airline ?? "")
                    .foregroundColor(.secondary)
            }
            .font(.footnote)
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.08)))
    }
}
