//
//  StoreMigration.swift
//  Idle Tapper — Store relocation logic
//
//  Turning the app sandbox off (required so Sparkle can replace the bundle in
//  /Applications) moves where SwiftData keeps its database. A sandboxed app
//  writes inside its container; an unsandboxed one writes to the real
//  Application Support directory. Without help, the first unsandboxed launch
//  would open an empty store and every recorded tap would look lost.
//
//  This file is the pure half of the fix: it decides *whether* to migrate and
//  *which* files that involves. The copying itself lives in `StoreMigrator`.
//

import Foundation

/// What the first unsandboxed launch should do about the old container store.
enum StoreMigrationPlan: Equatable {
    /// A store already exists at the destination — never overwrite it.
    case destinationOccupied
    /// No legacy store to bring across; this is a clean install.
    case nothingToMigrate
    /// Copy the store and its sidecars across.
    case copy
}

/// Pure decisions about relocating the SwiftData store.
enum StoreMigration {

    /// SQLite in WAL mode is three files, not one.
    ///
    /// The write-ahead log routinely holds committed transactions that have not
    /// been checkpointed back into the main file yet — at the time this was
    /// written the app's own `-wal` was 1.7 MB against a 72 KB store. Copying
    /// only `default.store` would silently discard the most recent taps, which
    /// is precisely the data a user would notice missing.
    static let sidecarSuffixes = ["", "-wal", "-shm"]

    /// Every file making up the store at `url`.
    static func storeFiles(for url: URL) -> [URL] {
        sidecarSuffixes.map { suffix in
            suffix.isEmpty
                ? url
                : url.deletingLastPathComponent()
                    .appendingPathComponent(url.lastPathComponent + suffix)
        }
    }

    /// Decide what to do, given only what exists on disk.
    ///
    /// Deliberately conservative: an occupied destination always wins. A stray
    /// `default.store` from an earlier build can sit at the unsandboxed path,
    /// and clobbering whatever is already there would be a worse failure than
    /// not migrating.
    static func plan(legacyStoreExists: Bool, destinationStoreExists: Bool) -> StoreMigrationPlan {
        if destinationStoreExists { return .destinationOccupied }
        return legacyStoreExists ? .copy : .nothingToMigrate
    }
}
