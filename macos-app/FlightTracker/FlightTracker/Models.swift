import Foundation

struct FlightEntry: Identifiable, Decodable {
    let id = UUID()
    let callsign: String?
    let origin: String?
    let destination: String?
    let distance: Double?
    let direction: String?
    let airline: String?
    let plane: String?
}

final class FlightStore: ObservableObject {
    static let defaultServerURL = URL(string: "http://127.0.0.1:8080")!

    @Published var closest: [FlightEntry] = []
    @Published var farthest: [FlightEntry] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var serverURL: URL = FlightStore.defaultServerURL

    private var session: URLSession = .shared

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

        fetch(path: "closest/json") { self.closest = $0 }
        fetch(path: "farthest/json") { self.farthest = $0 }

        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
}
