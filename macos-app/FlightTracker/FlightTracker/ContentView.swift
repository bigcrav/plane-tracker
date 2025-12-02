import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: FlightStore
    @State private var serverText: String = FlightStore.defaultServerURL.absoluteString

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            HStack(spacing: 16) {
                FlightList(title: "Closest flights", flights: store.closest)
                FlightList(title: "Farthest flights", flights: store.farthest)
            }
            HistoryList(entries: store.history)
            Spacer()
        }
        .padding(20)
        .task {
            serverText = store.serverURL.absoluteString
            store.load()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plane Tracker")
                    .font(.title2).fontWeight(.semibold)
                Text("Server: \(store.serverURL.absoluteString)")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            Spacer()
            TextField("Server URL", text: $serverText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            Button("Set & Refresh") {
                if let url = URL(string: serverText) {
                    store.load(server: url)
                }
            }
            Button("Refresh") {
                store.load()
            }
            if store.isLoading {
                ProgressView().scaleEffect(0.8)
            }
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottomLeading) {
            if let error = store.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.top, 4)
            }
        }
    }
}

struct FlightList: View {
    let title: String
    let flights: [FlightEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if flights.isEmpty {
                Text("No data yet").foregroundColor(.secondary)
            } else {
                List(flights) { flight in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(flight.callsign ?? "UNKNOWN")
                            .fontWeight(.semibold)
                        Text("\(flight.origin ?? "UNK") → \(flight.destination ?? "UNK")")
                            .foregroundColor(.secondary)
                        HStack {
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
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 240)
    }
}

struct HistoryList: View {
    let entries: [FlightEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent history").font(.headline)
            if entries.isEmpty {
                Text("No history yet").foregroundColor(.secondary)
            } else {
                List(entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.callsign ?? "UNKNOWN")
                                .fontWeight(.semibold)
                            Spacer()
                            if let ts = entry.timestamp {
                                Text(ts).foregroundColor(.secondary)
                            }
                        }
                        Text("\(entry.origin ?? "UNK") → \(entry.destination ?? "UNK")")
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            if let d = entry.distance {
                                Text(String(format: "%.1f", d))
                            }
                            Text(entry.direction ?? "")
                            Spacer()
                            Text(entry.airline ?? "")
                                .foregroundColor(.secondary)
                        }
                        .font(.footnote)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
                .frame(minHeight: 200)
            }
        }
    }
}
