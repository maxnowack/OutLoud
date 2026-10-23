import Foundation
import Network
import Observation

/// Whether the device is online, and whether the connection is expensive — cellular data or a
/// hotspot — so that a large download asks first (`docs/SPEC.md` §"Models").
@MainActor
@Observable
public final class NetworkMonitor {
    public private(set) var isConnected = true
    public private(set) var isExpensive = false
    @ObservationIgnored private let monitor = NWPathMonitor()

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            Task { @MainActor [weak self] in
                self?.isConnected = connected
                self?.isExpensive = expensive
            }
        }
        monitor.start(queue: DispatchQueue(label: "Outloud.NetworkMonitor"))
    }

    isolated deinit {
        monitor.cancel()
    }
}
