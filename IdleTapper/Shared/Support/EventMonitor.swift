//
//  EventMonitor.swift
//  Idle Tapper — Support
//
//  Wraps a global `NSEvent` monitor so its token is removed automatically when
//  the owner is released. Non-isolated so teardown is valid from any context.
//

import AppKit

/// Starts and stops a global event monitor, unregistering on deallocation.
final class EventMonitor {

    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: @Sendable (NSEvent) -> Void

    /// - Parameters:
    ///   - mask: Event types to observe.
    ///   - handler: Called for each matching event outside the app.
    init(mask: NSEvent.EventTypeMask, handler: @escaping @Sendable (NSEvent) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    /// Begin observing. Safe to call when already running.
    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    /// Stop observing. Safe to call when not running.
    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
}
