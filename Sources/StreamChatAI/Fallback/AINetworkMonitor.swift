//
// Copyright © 2026 Stream.io Inc. All rights reserved.
//

import Combine
import Foundation
import Network

/// Whether this device has a network connection.
///
/// A message sent through Stream Chat while offline doesn't fail: the SDK keeps it and sends
/// it once the device is back online. Check `isOnline` to answer such a message with a
/// fallback model right away, rather than waiting for an error that never comes.
@MainActor
public final class AINetworkMonitor: ObservableObject {
    /// One monitor for the whole app.
    public static let shared = AINetworkMonitor()

    /// Whether the device has a usable network path. It says nothing about whether your
    /// backend answers.
    @Published public private(set) var isOnline = true

    private let monitor = NWPathMonitor()

    public init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in
                guard let self, self.isOnline != online else { return }
                self.isOnline = online
            }
        }
        monitor.start(queue: DispatchQueue(label: "io.getstream.ai.network-monitor"))
    }

    deinit {
        monitor.cancel()
    }
}
