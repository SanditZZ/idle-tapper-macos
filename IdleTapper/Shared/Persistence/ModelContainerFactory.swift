//
//  ModelContainerFactory.swift
//  Idle Tapper — Persistence setup
//
//  Builds the SwiftData container. A menu bar app has no `WindowGroup` to
//  attach `.modelContainer(...)` to, so the container is created here and
//  injected explicitly by the app delegate.
//

import Foundation
import SwiftData

/// Creates `ModelContainer` instances for the app and for tests.
enum ModelContainerFactory {

    /// Every `@Model` type the app persists. Adding a model here is all that is
    /// required for it to be included in the schema.
    static let schema = Schema([DayRecord.self])

    /// Container backed by the on-disk SQLite store in Application Support.
    ///
    /// The location is named explicitly (see `StoreLocations`) rather than left
    /// to SwiftData's default, and the store left behind by the sandboxed
    /// builds is brought across on the first launch that finds one.
    ///
    /// - Parameter url: Optional explicit store location, used by tests and by
    ///   anyone running multiple instances side by side. Supplying one skips
    ///   the migration, since it is only meaningful for the app's own store.
    static func makePersistent(at url: URL? = nil) throws -> ModelContainer {
        let storeURL: URL
        if let url {
            storeURL = url
        } else {
            StoreMigrator.migrateIfNeeded()
            storeURL = StoreLocations.storeURL
        }

        // SwiftData will not create intermediate directories for a store URL it
        // was handed, and the app owns a subdirectory that may not exist yet.
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            AppLog.persistence.info(
                "[Persistence] Opened persistent store at \(storeURL.path, privacy: .public)"
            )
            return container
        } catch {
            AppLog.persistence.error(
                "[Persistence] Failed to open persistent store: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }

    /// Ephemeral container that never touches disk. Used by unit tests and
    /// SwiftUI previews.
    static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Last-resort container used when the on-disk store cannot be opened —
    /// for example a corrupt or unreadable database.
    ///
    /// The app stays usable and the session is still counted; only persistence
    /// across launches is lost. Preferred over crashing on launch, and the
    /// caller is expected to tell the user.
    static func makeFallback() -> ModelContainer? {
        do {
            let container = try makeInMemory()
            AppLog.persistence.warning("[Persistence] Falling back to an in-memory store — history will not persist")
            return container
        } catch {
            AppLog.persistence.error(
                "[Persistence] Fallback in-memory store also failed: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}
