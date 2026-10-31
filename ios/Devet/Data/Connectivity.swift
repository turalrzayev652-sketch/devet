import Combine
import Network

/// Online/offline for the offline strip (screens.md §1: offline → strip, main action disabled).
@MainActor
final class Connectivity: ObservableObject {
    @Published private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    init(start: Bool = true) {
        guard start else { return }
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.isOnline = path.status == .satisfied }
        }
        monitor.start(queue: DispatchQueue(label: "az.devet.connectivity"))
    }

    /// For previews and tests.
    static func fixed(_ online: Bool) -> Connectivity {
        let c = Connectivity(start: false)
        c.isOnline = online
        return c
    }

    deinit { monitor.cancel() }
}
