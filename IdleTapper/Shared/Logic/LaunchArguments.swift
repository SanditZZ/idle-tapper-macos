//
//  LaunchArguments.swift
//  Idle Tapper — Launch argument parsing
//
//  A locally built copy of the app opens the same database as the installed
//  one, because `AppEnvironment` asks for the default store location. That
//  makes UI testing destructive: every tap driven from a script is permanent,
//  real history, and "Delete All History" can never be exercised at all.
//
//  `--store-path` redirects the store somewhere disposable. It is honoured in
//  Debug builds only (see `AppEnvironment`), so a released copy cannot be
//  pointed at another database by whoever launches it.
//
//  This file is the pure half: it turns an argument list into a decision, with
//  no filesystem access and no knowledge of what the caller does next.
//

import Foundation

/// What the launch arguments say about where the store should live.
enum StoreOverride: Equatable {
    /// No `--store-path` was given; use the app's own store.
    case none
    /// Use this location instead.
    case use(URL)
    /// A `--store-path` was given but cannot be used.
    ///
    /// Deliberately distinct from `.none`: the caller must not quietly fall
    /// back to the real store, because the whole point of passing the flag is
    /// that the real store is not to be touched.
    case invalid(reason: String)

    /// The location to open, or `nil` to use the app's own store.
    var url: URL? {
        if case .use(let url) = self { return url }
        return nil
    }
}

/// Pure reading of the process's launch arguments.
enum LaunchArguments {

    /// Redirects the SwiftData store. Accepts `--store-path <path>` and
    /// `--store-path=<path>`.
    static let storePathFlag = "--store-path"

    /// Decide where the store should live, given only the argument list.
    ///
    /// - Parameter arguments: Defaults to the real process arguments; tests
    ///   pass their own.
    static func storeOverride(in arguments: [String] = CommandLine.arguments) -> StoreOverride {
        guard let value = value(for: storePathFlag, in: arguments) else { return .none }

        guard let value, !value.isEmpty else {
            return .invalid(reason: "\(storePathFlag) was given without a path")
        }

        // An app launched by `open` inherits `/` as its working directory, so a
        // relative path would resolve somewhere the caller did not intend and
        // almost certainly cannot write. Rejecting is clearer than obeying.
        guard value.hasPrefix("/") else {
            return .invalid(reason: "\(storePathFlag) needs an absolute path, got \(value)")
        }

        return .use(URL(fileURLWithPath: value).standardizedFileURL)
    }

    /// The value attached to `flag`, in either supported form.
    ///
    /// Returns `nil` when the flag is absent, and `.some(nil)` when it is
    /// present but carries no value — two cases the caller must tell apart.
    private static func value(for flag: String, in arguments: [String]) -> String?? {
        for (index, argument) in arguments.enumerated() {
            if argument == flag {
                let next = arguments[safe: index + 1]
                // A following flag is the next argument, not this one's value.
                if let next, !next.hasPrefix("-") { return .some(next) }
                return .some(nil)
            }
            if argument.hasPrefix(flag + "=") {
                return .some(String(argument.dropFirst(flag.count + 1)))
            }
        }
        return nil
    }
}

private extension Array {
    /// Bounds-checked access, so a trailing flag reads as absent rather than
    /// trapping.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
