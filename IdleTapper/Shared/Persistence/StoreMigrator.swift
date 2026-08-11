//
//  StoreMigrator.swift
//  Idle Tapper — Store relocation
//
//  The side-effecting half of `StoreMigration`: copies the sandboxed store to
//  the unsandboxed location on first launch after the sandbox was removed.
//
//  Copies, never moves. The container copy stays put as a free backup — if
//  anything about this goes wrong the original database is still sitting
//  exactly where it always was, and the user loses nothing.
//

import Foundation

/// Moves the SwiftData store out of the old sandbox container.
enum StoreMigrator {

    /// Outcome of a migration attempt, for logging and for tests.
    enum Outcome: Equatable {
        case migrated(fileCount: Int)
        case skipped(StoreMigrationPlan)
        case failed(String)
    }

    /// Copy the legacy container store to `destination` when appropriate.
    ///
    /// Safe to call on every launch: once the destination exists the plan comes
    /// back `.destinationOccupied` and nothing happens. Never throws — a failed
    /// migration must not stop the app launching, it just means starting from
    /// an empty history with the original left intact.
    @discardableResult
    static func migrateIfNeeded(
        from legacy: URL = StoreLocations.legacyContainerStoreURL(),
        to destination: URL = StoreLocations.storeURL,
        fileManager: FileManager = .default
    ) -> Outcome {
        let plan = StoreMigration.plan(
            legacyStoreExists: fileManager.fileExists(atPath: legacy.path),
            destinationStoreExists: fileManager.fileExists(atPath: destination.path)
        )

        guard plan == .copy else {
            AppLog.persistence.debug(
                "[Persistence] Store migration not needed (\(String(describing: plan), privacy: .public))"
            )
            return .skipped(plan)
        }

        AppLog.persistence.info("[Persistence] Migrating store out of the sandbox container")

        do {
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            // Copy the store and both sidecars. Only the main file is required;
            // a store with no -wal is simply one with nothing uncheckpointed.
            var copied = 0
            for (source, target) in zip(
                StoreMigration.storeFiles(for: legacy),
                StoreMigration.storeFiles(for: destination)
            ) where fileManager.fileExists(atPath: source.path) {
                try fileManager.copyItem(at: source, to: target)
                copied += 1
            }

            AppLog.persistence.info(
                "[Persistence] Store migration copied \(copied, privacy: .public) file(s); the original was left in place"
            )
            return .migrated(fileCount: copied)
        } catch {
            // Leave any partial copy behind rather than deleting: the store is
            // about to be opened, and a half-written database that fails to
            // open degrades to the in-memory fallback, which is survivable.
            AppLog.persistence.error(
                "[Persistence] Store migration failed: \(error.localizedDescription, privacy: .public)"
            )
            return .failed(error.localizedDescription)
        }
    }
}
