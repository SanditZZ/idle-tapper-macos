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

        do {
            container = try ModelContainerFactory.makePersistent()
        } catch {
            AppLog.app.error(
                "[App] Persistent store unavailable, falling back to memory: \(error.localizedDescription, privacy: .public)"
            )
            container = ModelContainerFactory.makeFallback()
            ephemeral = true
        }

        guard let container else {
            // Both the persistent and in-memory stores failed, which indicates
            // a broken SwiftData runtime rather than a recoverable condition.
            fatalError("[App] Could not create any model container")
        }

        self.isEphemeral = ephemeral
        self.launchAtLogin = LaunchAtLoginService()
        self.tracker = TapTracker(
            repository: SwiftDataTapRepository(container: container),
            settings: settings,
            isEphemeral: ephemeral
        )

        AppLog.app.info("[App] Environment ready (ephemeral: \(ephemeral, privacy: .public))")
    }
}
