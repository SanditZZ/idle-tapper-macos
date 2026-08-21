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
        static let dailyGoal = "dailyGoal"
        static let goalRemindersEnabled = "goalRemindersEnabled"
        static let goalReminderHour = "goalReminderHour"
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

    /// Today's tap target. `0` means the goal is switched off.
    ///
    /// Off by default, and deliberately so: the goal changes what a streak
    /// means — a day counts once it reaches this number rather than on any tap
    /// at all — and imposing that on someone who upgraded without asking for it
    /// would put an existing streak at risk overnight. Anyone who never opens
    /// this keeps exactly the app they had.
    ///
    /// Note this is *not* the value a past day is judged against. Each day
    /// records the goal that was in effect on it (`DayRecord.goalTarget`), so
    /// editing this only ever affects today onwards.
    var dailyGoal: Int {
        didSet {
            let clamped = Self.clampDailyGoal(dailyGoal)
            if clamped != dailyGoal {
                dailyGoal = clamped
                return
            }
            defaults.set(dailyGoal, forKey: Key.dailyGoal)
            AppLog.settings.info("[Settings] Daily goal set to \(self.dailyGoal, privacy: .public)")
        }
    }

    /// Whether to send a notification late in the day when the streak is at
    /// risk of ending.
    ///
    /// Independent of `dailyGoal`: the streak exists whether or not a goal is
    /// set, so the reminder is useful either way. It says "tap once before
    /// midnight" with no goal, and "N taps to go" with one.
    var goalRemindersEnabled: Bool {
        didSet { defaults.set(goalRemindersEnabled, forKey: Key.goalRemindersEnabled) }
    }

    /// Local hour, `0...23`, at which the streak reminder fires.
    ///
    /// User-chosen rather than fixed. Eight in the evening is a reasonable
    /// default and a poor universal: it is the middle of the working day for
    /// someone whose hours run the other way round, and any fixed hour is wrong
    /// for somebody.
    var goalReminderHour: Int {
        didSet {
            let clamped = Self.clampReminderHour(goalReminderHour)
            if clamped != goalReminderHour {
                goalReminderHour = clamped
                return
            }
            defaults.set(goalReminderHour, forKey: Key.goalReminderHour)
        }
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

        // `integer(forKey:)` reads a missing key as 0, which is exactly what
        // "no goal set" means here — so a fresh install needs no special case.
        self.dailyGoal = Self.clampDailyGoal(defaults.integer(forKey: Key.dailyGoal))
        self.goalRemindersEnabled =
            defaults.object(forKey: Key.goalRemindersEnabled) as? Bool ?? false

        // Unlike the goal, 0 is a *valid* hour here (midnight), so a missing
        // key cannot be told from a real zero by reading the integer alone.
        self.goalReminderHour = (defaults.object(forKey: Key.goalReminderHour) as? Int)
            .map(Self.clampReminderHour) ?? Self.defaultGoalReminderHour
    }

    // MARK: - Calculations

    static let defaultHistoryRangeDays = 30
    static let historyRangeBounds = 7...365

    /// Keep the range inside supported bounds so a corrupt default cannot
    /// produce an unusable chart.
    static func clampHistoryRange(_ value: Int) -> Int {
        min(max(value, historyRangeBounds.lowerBound), historyRangeBounds.upperBound)
    }

    /// 20:00. Late enough to be a last call, early enough to act on.
    static let defaultGoalReminderHour = 20

    static let goalReminderHourBounds = 0...23

    /// Clamp a goal, preserving `0` as the off switch.
    ///
    /// Anything negative also reads as off rather than being pulled up to the
    /// minimum: a corrupt preference should disable the feature, not silently
    /// enable one the user never chose.
    static func clampDailyGoal(_ value: Int) -> Int {
        guard value > 0 else { return 0 }
        return GoalCalculator.normalized(value) ?? 0
    }

    static func clampReminderHour(_ value: Int) -> Int {
        min(max(value, goalReminderHourBounds.lowerBound), goalReminderHourBounds.upperBound)
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
        dailyGoal = 0
        goalRemindersEnabled = false
        goalReminderHour = Self.defaultGoalReminderHour
        AppLog.settings.info("[Settings] Restored defaults")
    }
}
