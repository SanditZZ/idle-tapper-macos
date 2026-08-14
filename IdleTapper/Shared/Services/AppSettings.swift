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
        static let showVisualEffects = "showVisualEffects"
        static let rightClickTaps = "rightClickTaps"
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

    /// Whether crossing a milestone plays a particle burst.
    ///
    /// Only the celebration is optional — the milestone banner is not, because
    /// it is what says which number was reached and is the only part of this a
    /// screen reader ever hears.
    ///
    /// Separate from the system's Reduce Motion setting on purpose: that one
    /// means "moving things make me unwell", this one means "I find it
    /// distracting". Either suppresses the burst, and neither implies the other.
    var showVisualEffects: Bool {
        didSet { defaults.set(showVisualEffects, forKey: Key.showVisualEffects) }
    }

    /// Whether right-clicking the tap button counts a tap.
    ///
    /// On by default: the feature adds a way to tap and takes nothing away, so
    /// the default has to be the working one. Off is for people who right-click
    /// by habit and do not want a stray press counted.
    ///
    /// Turning it off removes the event monitor rather than making it ignore
    /// events, so nothing is left watching.
    var rightClickTaps: Bool {
        didSet { defaults.set(rightClickTaps, forKey: Key.rightClickTaps) }
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
        self.showVisualEffects = defaults.object(forKey: Key.showVisualEffects) as? Bool ?? true
        self.rightClickTaps = defaults.object(forKey: Key.rightClickTaps) as? Bool ?? true
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
        showVisualEffects = true
        rightClickTaps = true
        AppLog.settings.info("[Settings] Restored defaults")
    }
}
