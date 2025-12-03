import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject private var store: FlightStore
    @StateObject private var locationProvider = LocationProvider()
    @State private var latText: String = ""
    @State private var lonText: String = ""
    @State private var radiusText: String = ""
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: AppConfiguration.homeLatitude, longitude: AppConfiguration.homeLongitude),
        span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
    )
    @State private var selectedFlight: FlightEntry?

    var body: some View {
        ZStack {
            background
            ScrollView {
                VStack(spacing: 24) {
                    header
                    HomeSettings(
                        latText: $latText,
                        lonText: $lonText,
                        radiusText: $radiusText,
                        onApply: applyHomeSettings,
                        onUseCurrent: useCurrentLocation
                    )
                    MapCard(region: $mapRegion, selectedFlight: selectedFlight ?? store.closest.first, radiusMiles: store.radiusMiles, home: homeCoordinate)
                    FlightDetailsCard(flight: selectedFlight ?? store.closest.first)
                    HStack(spacing: 18) {
                        FlightList(title: "Closest flights", flights: store.closest) { flight in
                            selectFlight(flight)
                        }
                        FlightList(title: "Farthest flights", flights: store.farthest)
                    }
                    HistoryList(entries: store.history)
                }
                .padding(24)
            }
        }
        .task {
            latText = String(format: "%.6f", store.homeLatitude)
            lonText = String(format: "%.6f", store.homeLongitude)
            radiusText = String(format: "%.1f", store.radiusMiles)
            updateRegion()
            store.load()
        }
        .onReceive(locationProvider.$currentLocation) { location in
            guard let location else { return }
            latText = String(format: "%.6f", location.coordinate.latitude)
            lonText = String(format: "%.6f", location.coordinate.longitude)
            updateRegion(center: location.coordinate)
            store.updateHome(lat: location.coordinate.latitude, lon: location.coordinate.longitude, radius: store.radiusMiles)
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
                    useCurrentLocation()
                } label: {
                    Label("Use current", systemImage: "location.fill")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.15)))
                }
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
        updateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }

    private func useCurrentLocation() {
        locationProvider.requestLocation()
    }

    private func updateRegion(center: CLLocationCoordinate2D? = nil) {
        let center = center ?? CLLocationCoordinate2D(latitude: store.homeLatitude, longitude: store.homeLongitude)
        mapRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: max(0.2, store.radiusMiles / 40), longitudeDelta: max(0.2, store.radiusMiles / 40))
        )
    }

    private var homeCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: Double(latText) ?? store.homeLatitude, longitude: Double(lonText) ?? store.homeLongitude)
    }

    private func selectFlight(_ flight: FlightEntry) {
        selectedFlight = flight
        if let coordinate = flight.coordinate {
            updateRegion(center: coordinate)
        }
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
    let onUseCurrent: () -> Void

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
                        onUseCurrent()
                    } label: {
                        Label("Use Current", systemImage: "location")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
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
    var onSelect: ((FlightEntry) -> Void)? = nil

    var body: some View {
        GlassPanel(title: title, subtitle: nil) {
            if flights.isEmpty {
                Text("No data yet").foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(flights) { flight in
                            FlightRowView(flight: flight, showTimestamp: false)
                                .contentShape(Rectangle())
                                .onTapGesture { onSelect?(flight) }
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

struct MapCard: View {
    @Binding var region: MKCoordinateRegion
    let selectedFlight: FlightEntry?
    let radiusMiles: Double
    let home: CLLocationCoordinate2D

    var body: some View {
        GlassPanel(title: "Map", subtitle: "Closest plane in range") {
            Map(coordinateRegion: $region, annotationItems: pins) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    VStack(spacing: 4) {
                        Image(systemName: item.isPlane ? "airplane.circle.fill" : "house.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, item.isPlane ? .blue : .green)
                        Text(item.title)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }
            .overlay(alignment: .center) {
                Circle()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 2)
                    .padding(32)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading) {
                    Text(String(format: "Radius: %.1f mi", radiusMiles))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let coordinate = selectedFlight?.coordinate {
                        Text("Bearing: \(selectedFlight?.direction ?? "-")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "Lat %.3f, Lon %.3f", coordinate.latitude, coordinate.longitude))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: "Home %.3f, %.3f", home.latitude, home.longitude))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(8)
            }
            .frame(minHeight: 260)
        }
    }

    private var pins: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = [
            MapAnnotationItem(id: UUID(), coordinate: home, title: "Home", isPlane: false)
        ]
        if let flight = selectedFlight, let coordinate = flight.coordinate {
            items.append(MapAnnotationItem(id: flight.id, coordinate: coordinate, title: flight.callsign ?? "Plane", isPlane: true))
        }
        return items
    }
}

private struct MapAnnotationItem: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String
    let isPlane: Bool
}

struct FlightDetailsCard: View {
    let flight: FlightEntry?

    var body: some View {
        GlassPanel(title: "Flight info", subtitle: "Closest plane to your location") {
            if let flight {
                VStack(alignment: .leading, spacing: 8) {
                    Text(flight.callsign ?? "Unknown")
                        .font(.title3.weight(.semibold))
                    Text("\(flight.origin ?? "Unknown") → \(flight.destination ?? "Unknown")")
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        if let distance = flight.distance {
                            Label(String(format: "%.1f mi", distance), systemImage: "mappin.and.ellipse")
                        }
                        if let dir = flight.direction {
                            Label(dir, systemImage: "location.north.line")
                        }
                        if let altitude = flight.altitude {
                            Label(String(format: "%.0f ft", altitude), systemImage: "chevron.up")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            } else {
                Text("No flight selected yet.")
                    .foregroundColor(.secondary)
            }
        }
    }
}
