//
//  ObserverBag.swift
//  Idle Tapper — Support
//
//  Owns `NotificationCenter` observer tokens and removes them when it is
//  released, so observing types do not need cleanup code in `deinit`. Kept
//  non-isolated so it can be torn down from any context.
//

import Foundation

/// Holds observer tokens and unregisters them on deallocation.
final class ObserverBag {

    private struct Entry {
        let token: any NSObjectProtocol
        let center: NotificationCenter
    }

    private var entries: [Entry] = []

    init() {}

    deinit {
        for entry in entries {
            entry.center.removeObserver(entry.token)
        }
    }

    /// Observe `name` on `center`, retaining the token for later removal.
    func observe(
        _ name: Notification.Name,
        on center: NotificationCenter = .default,
        object: Any? = nil,
        queue: OperationQueue? = .main,
        using handler: @escaping @Sendable (Notification) -> Void
    ) {
        let token = center.addObserver(
            forName: name,
            object: object,
            queue: queue,
            using: handler
        )
        entries.append(Entry(token: token, center: center))
    }

    /// Remove every observer immediately.
    func removeAll() {
        for entry in entries {
            entry.center.removeObserver(entry.token)
        }
        entries.removeAll()
    }
}
