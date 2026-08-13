//
//  AppEnvironment.swift
//  Idle Tapper — Composition root
//
//  Builds the object graph once and hands it to whoever needs it. Concrete
//  types are chosen here and nowhere else, so swapping the persistence backend
//  is a one-line change.
//

import Foundation
import SwiftData

/// The app's live dependency graph.
@MainActor
final class AppEnvironment {

    /// Shared graph used by the app. Tests build their own instances directly
    /// rather than going through this.
    static let shared = AppEnvironment()

    let settings: AppSettings
    let tracker: TapTracker
    let launchAtLogin: LaunchAtLoginService
    let updates: UpdateService

    /// True when the on-disk store could not be opened and history is being
    /// held in memory only. Surfaced in the UI rather than failing silently.
    let isEphemeral: Bool

    private init() {
        let settings = AppSettings.shared
        self.settings = settings

        // Prefer the persistent store; fall back to memory so a corrupt
        // database degrades to "history not saved" instead of a launch crash.
        var container: ModelContainer?
        var ephemeral = false

        let storeOverride = Self.storeOverride
        if case .invalid(let reason) = storeOverride {
            // Never fall through to the app's own store here. Someone passed
            // --store-path precisely so the real history would not be written
            // to; honouring the request badly is worse than not running.
            AppLog.app.error(
                "[App] Unusable \(LaunchArguments.storePathFlag, privacy: .public): \(reason, privacy: .public) — refusing the app's own store, history will not be saved"
            )
            container = ModelContainerFactory.makeFallback()
            ephemeral = true
        } else {
            if let url = storeOverride.url {
                AppLog.app.info(
                    "[App] Store redirected by launch argument to \(url.path, privacy: .public)"
                )
            }
            do {
                container = try ModelContainerFactory.makePersistent(at: storeOverride.url)
            } catch {
                AppLog.app.error(
                    "[App] Persistent store unavailable, falling back to memory: \(error.localizedDescription, privacy: .public)"
                )
                container = ModelContainerFactory.makeFallback()
                ephemeral = true
            }
        }

        guard let container else {
            // Both the persistent and in-memory stores failed, which indicates
            // a broken SwiftData runtime rather than a recoverable condition.
            fatalError("[App] Could not create any model container")
        }

        self.isEphemeral = ephemeral
        self.launchAtLogin = LaunchAtLoginService()
        self.updates = UpdateService.shared
        self.tracker = TapTracker(
            repository: SwiftDataTapRepository(container: container),
            settings: settings,
            isEphemeral: ephemeral
        )

        // Ships on; applied once so it never overrides a later opt-out.
        self.launchAtLogin.applyFirstRunDefault()

        AppLog.app.info("[App] Environment ready (ephemeral: \(ephemeral, privacy: .public))")
    }

    /// Where this build is willing to keep its database.
    ///
    /// Debug builds honour `--store-path`, so UI testing can be driven against
    /// a disposable store instead of the user's real history. A release build
    /// always uses the app's own store: nothing an end user is handed should be
    /// redirectable to another database by whoever launches it.
    private static var storeOverride: StoreOverride {
        #if DEBUG
        return LaunchArguments.storeOverride()
        #else
        return .none
        #endif
    }
}
