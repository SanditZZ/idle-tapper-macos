//
//  StoreLocations.swift
//  Idle Tapper — Where the database lives
//
//  The app names its store explicitly rather than accepting SwiftData's
//  default. Unsandboxed, that default is a bare `default.store` dropped
//  directly into ~/Library/Application Support — a directory shared with every
//  other app on the Mac, where a generic filename is asking for a collision.
//  One was already sitting there from an earlier build of this app.
//
//  An owned subdirectory with an owned filename removes that class of problem
//  entirely, and makes the migration below deterministic: the destination is a
//  path only this app has ever written.
//

import Foundation

/// Filesystem locations for the SwiftData store.
enum StoreLocations {

    /// Directory the app keeps its database in: `~/Library/Application Support/IdleTapper`.
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("IdleTapper", isDirectory: true)
    }

    /// The live store: `~/Library/Application Support/IdleTapper/IdleTapper.store`.
    static var storeURL: URL {
        supportDirectory.appendingPathComponent("IdleTapper.store")
    }

    /// Where the sandboxed builds kept their database.
    ///
    /// Built from the real home directory rather than `applicationSupportDirectory`,
    /// which resolves *into* the container when sandboxed and would therefore
    /// point at the destination rather than the source.
    static func legacyContainerStoreURL(
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) -> URL {
        let identifier = bundleIdentifier ?? "com.kkpon3.IdleTapper"
        return URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers")
            .appendingPathComponent(identifier)
            .appendingPathComponent("Data/Library/Application Support/default.store")
    }
}
