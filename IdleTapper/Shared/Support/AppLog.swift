//
//  AppLog.swift
//  Idle Tapper — Structured logging
//
//  One logger per module so Console.app can be filtered by category. Messages
//  carry a `[Module]` prefix as well, which keeps them readable when logs are
//  exported as plain text.
//

import Foundation
import OSLog

/// Namespaced loggers. Use the logger matching the module you are in.
enum AppLog {
    /// Reverse-DNS subsystem, resolved from the bundle so forks get their own.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.kkpon3.IdleTapper"

    /// App lifecycle: launch, termination, window coordination.
    static let app = Logger(subsystem: subsystem, category: "App")

    /// Menu bar item and popover presentation.
    static let menuBar = Logger(subsystem: subsystem, category: "MenuBar")

    /// Tap recording and daily rollover.
    static let tap = Logger(subsystem: subsystem, category: "Tap")

    /// SwiftData container, fetches and saves.
    static let persistence = Logger(subsystem: subsystem, category: "Persistence")

    /// User settings and preferences.
    static let settings = Logger(subsystem: subsystem, category: "Settings")

    /// Daily goal: progress, celebration and reminder scheduling.
    static let goal = Logger(subsystem: subsystem, category: "Goal")

    /// Sparkle update checks, downloads and installs.
    static let updates = Logger(subsystem: subsystem, category: "Updates")
}
