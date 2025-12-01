import SwiftUI

@main
struct PlaneTrackerApp: App {
    @StateObject private var store = FlightStore()

    var body: some Scene {
        WindowGroup("Plane Tracker") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 520, minHeight: 420)
        }
    }
}
