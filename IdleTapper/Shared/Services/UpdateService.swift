//
//  UpdateService.swift
//  Idle Tapper — Automatic updates
//
//  Wraps Sparkle. The app is not notarized by Apple — that needs the paid
//  Developer Program — so Sparkle's own EdDSA signature is what makes an
//  update trustworthy: it refuses any archive that does not verify against the
//  public key baked into Info.plist.
//
//  A pleasant side effect is that Gatekeeper's quarantine prompt becomes a
//  one-time cost. Sparkle performs the install itself, so updates after the
//  first manual download never re-trigger it.
//

import Foundation
import Observation
import Sparkle

/// Observable façade over Sparkle's updater.
@MainActor
@Observable
final class UpdateService {

    /// Shared instance. Sparkle expects a single long-lived updater.
    static let shared = UpdateService()

    // MARK: - Data

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private let driverDelegate: GentleReminderDelegate
    @ObservationIgnored private let updaterDelegate: UpdaterDelegate
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?

    /// False while a check is already running, so the button can disable.
    private(set) var canCheck: Bool = true

    /// Whether Sparkle checks on its own schedule. Sparkle persists this to
    /// user defaults itself; `Info.plist` supplies the initial value (on).
    var automaticallyChecks: Bool {
        didSet {
            controller.updater.automaticallyChecksForUpdates = automaticallyChecks
            AppLog.updates.info(
                "[Updates] Automatic checks \(self.automaticallyChecks ? "enabled" : "disabled", privacy: .public)"
            )
        }
    }

    /// When Sparkle last completed a check, or nil if it never has.
    var lastCheckDate: Date? { controller.updater.lastUpdateCheckDate }

    /// Human-readable outcome of the most recent check, for Settings.
    private(set) var lastCheckSummary: String?

    // MARK: - Lifecycle

    private init() {
        driverDelegate = GentleReminderDelegate()
        updaterDelegate = UpdaterDelegate()

        // `startingUpdater: true` begins the background schedule immediately.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: driverDelegate
        )

        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        canCheck = controller.updater.canCheckForUpdates

        // `canCheckForUpdates` flips while a check is in flight; observing it
        // keeps the Settings button honest instead of letting the user start a
        // second check that Sparkle would ignore.
        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.new]
        ) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor in self?.canCheck = value }
        }

        updaterDelegate.onCycleFinished = { [weak self] summary in
            Task { @MainActor in self?.lastCheckSummary = summary }
        }

        AppLog.updates.info(
            "[Updates] Sparkle ready (automatic: \(self.automaticallyChecks, privacy: .public), feed: \(self.controller.updater.feedURL?.absoluteString ?? "none", privacy: .public))"
        )
    }

    // MARK: - Actions

    /// Check now, showing Sparkle's standard UI.
    func checkForUpdates() {
        AppLog.updates.info("[Updates] Manual check requested")
        lastCheckSummary = "Checking…"
        controller.checkForUpdates(nil)
    }
}

// MARK: - Delegates

/// Lets a menu bar app show update prompts at all.
///
/// Sparkle assumes a regular app that can bring a window forward. Without
/// `supportsGentleScheduledUpdateReminders`, a scheduled update found by an
/// accessory app is discovered and then never surfaced — the user is simply
/// never told. This is required, not an enhancement.
private final class GentleReminderDelegate: NSObject, SPUStandardUserDriverDelegate {

    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // Let Sparkle present it. The app has no window of its own to
        // interrupt, so there is nothing to be polite about.
        true
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        AppLog.updates.info(
            "[Updates] Presenting update \(update.displayVersionString, privacy: .public)"
        )
    }
}

/// Reports check outcomes back to the UI.
private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {

    /// Called with a short description of how the last cycle ended.
    var onCycleFinished: ((String) -> Void)?

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        guard let error else {
            AppLog.updates.info("[Updates] Check finished: up to date or update offered")
            onCycleFinished?("Up to date.")
            return
        }

        // Sparkle reports "no update found" as an error. It is not one.
        let noUpdate = (error as NSError).code == Int(Sparkle.SUError.noUpdateError.rawValue)
        if noUpdate {
            AppLog.updates.info("[Updates] Check finished: no update available")
            onCycleFinished?("Up to date.")
            return
        }

        AppLog.updates.error(
            "[Updates] Check failed: \(error.localizedDescription, privacy: .public)"
        )
        // Until the appcast is published this is the expected path, and saying
        // so beats a bare network error the user cannot act on.
        onCycleFinished?("Could not reach the update feed.")
    }
}
