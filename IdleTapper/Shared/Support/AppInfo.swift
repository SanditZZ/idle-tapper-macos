//
//  AppInfo.swift
//  Idle Tapper — Bundle identity
//
//  One place that reads the bundle's version keys. `SettingsView` and
//  `AboutSettingsPage` each carried their own byte-identical copy of this, which
//  is two places to update and two places for a fallback to drift.
//

import Foundation

/// Identity of the running bundle.
enum AppInfo {

    /// The app's display name.
    static let name = "Idle Tapper"

    /// Marketing version, e.g. `0.1.2`.
    static var version: String {
        string(for: "CFBundleShortVersionString") ?? "0.0.0"
    }

    /// Build number, e.g. `3`. Sparkline orders updates by this, so it is worth
    /// showing next to the version rather than hiding it.
    static var build: String {
        string(for: "CFBundleVersion") ?? "0"
    }

    /// Version and build together, e.g. `0.1.2 (3)`.
    static var displayVersion: String {
        "\(version) (\(build))"
    }

    /// Reads an Info.plist string, treating an empty value as absent so a
    /// blank key falls back rather than rendering as nothing.
    private static func string(for key: String) -> String? {
        guard let value = Bundle.main.infoDictionary?[key] as? String,
              !value.isEmpty
        else { return nil }
        return value
    }
}
