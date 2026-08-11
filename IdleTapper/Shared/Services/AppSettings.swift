//
//  AppSettings.swift
//  Idle Tapper — Preferences
//
//  User preferences live in `UserDefaults`; tap history lives in SwiftData.
//  Keeping the two apart matters: defaults are loaded wholesale and are not a
//  datastore, while history is append-heavy and wants a real database.
//
//  Every property has a valid, functional default so a fresh install behaves
//  correctly with no setup.
//

import Foundation
import Observation

/// Observable wrapper over the app's user defaults.
@MainActor
@Observable
final class AppSettings {

    /// Shared instance used by the app. Tests construct their own against a
    /// scratch `UserDefaults` suite.
    static let shared = AppSettings()

    // MARK: - Keys

    private enum Key {
        static let menuBarDisplayStyle = "menuBarDisplayStyle"
        static let historyRangeDays = "historyRangeDays"
        static let confirmBeforeReset = "confirmBeforeReset"
        static let playTapSound = "playTapSound"
        static let suppressHiddenIconNotice = "suppressHiddenIconNotice"
    }

    // MARK: - Data

    @ObservationIgnored private let defaults: UserDefaults

    /// How the menu bar status item is rendered.
    var menuBarDisplayStyle: MenuBarDisplayStyle {
        didSet {
            defaults.set(menuBarDisplayStyle.rawValue, forKey: Key.menuBarDisplayStyle)
            AppLog.settings.info("[Settings] Menu bar style set to \(self.menuBarDisplayStyle.rawValue, privacy: .public)")
        }
    }

    /// Number of days shown in the history chart.
    var historyRangeDays: Int {
        didSet {
            let clamped = Self.clampHistoryRange(historyRangeDays)
            if clamped != historyRangeDays {
                historyRangeDays = clamped
                return
            }
            defaults.set(historyRangeDays, forKey: Key.historyRangeDays)
        }
    }

    /// Whether destructive history deletion asks for confirmation first.
    var confirmBeforeReset: Bool {
        didSet { defaults.set(confirmBeforeReset, forKey: Key.confirmBeforeReset) }
    }

    /// Whether a tap plays a short click.
    var playTapSound: Bool {
        didSet { defaults.set(playTapSound, forKey: Key.playTapSound) }
    }

    /// Whether the user has asked not to be told again that the menu bar icon
    /// is hidden behind the display notch.
    var suppressHiddenIconNotice: Bool {
        didSet { defaults.set(suppressHiddenIconNotice, forKey: Key.suppressHiddenIconNotice) }
    }

    // MARK: - Lifecycle

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedStyle = defaults.string(forKey: Key.menuBarDisplayStyle)
        self.menuBarDisplayStyle = storedStyle
            .flatMap(MenuBarDisplayStyle.init(rawValue:)) ?? .iconAndCount

        let storedRange = defaults.integer(forKey: Key.historyRangeDays)
        self.historyRangeDays = storedRange > 0
            ? Self.clampHistoryRange(storedRange)
            : Self.defaultHistoryRangeDays

        self.confirmBeforeReset = defaults.object(forKey: Key.confirmBeforeReset) as? Bool ?? true
        self.playTapSound = defaults.object(forKey: Key.playTapSound) as? Bool ?? false
        self.suppressHiddenIconNotice =
            defaults.object(forKey: Key.suppressHiddenIconNotice) as? Bool ?? false
    }

    // MARK: - Calculations

    static let defaultHistoryRangeDays = 30
    static let historyRangeBounds = 7...365

    /// Keep the range inside supported bounds so a corrupt default cannot
    /// produce an unusable chart.
    static func clampHistoryRange(_ value: Int) -> Int {
        min(max(value, historyRangeBounds.lowerBound), historyRangeBounds.upperBound)
    }

    /// Restore every preference to its default.
    func resetToDefaults() {
        menuBarDisplayStyle = .iconAndCount
        historyRangeDays = Self.defaultHistoryRangeDays
        confirmBeforeReset = true
        playTapSound = false
        suppressHiddenIconNotice = false
        AppLog.settings.info("[Settings] Restored defaults")
    }
}
