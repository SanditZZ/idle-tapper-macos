//
//  LaunchArgumentsTests.swift
//  IdleTapperTests
//
//  `--store-path` exists so UI testing stops writing to real history, which
//  means the failure that matters is not "the flag did not work" but "the flag
//  looked like it worked and the app opened the real store anyway". These cover
//  every way that could happen.
//

import Foundation
import Testing
@testable import IdleTapper

@Suite("Launch arguments")
struct LaunchArgumentsTests {

    /// Arguments always start with the executable path.
    private func arguments(_ rest: String...) -> [String] {
        ["/Applications/IdleTapper.app/Contents/MacOS/IdleTapper"] + rest
    }

    // MARK: - Absent

    @Test("No flag means the app's own store")
    func absentFlagUsesTheDefault() {
        #expect(LaunchArguments.storeOverride(in: arguments()) == .none)
        #expect(LaunchArguments.storeOverride(in: arguments("--other", "value")) == .none)
    }

    @Test("A store override is nil for every case except an accepted path")
    func onlyAnAcceptedPathProducesAURL() {
        #expect(StoreOverride.none.url == nil)
        #expect(StoreOverride.invalid(reason: "whatever").url == nil)
        #expect(StoreOverride.use(URL(fileURLWithPath: "/tmp/a.store")).url?.path == "/tmp/a.store")
    }

    // MARK: - Accepted

    @Test("Separate value form")
    func parsesSeparateValue() {
        let override = LaunchArguments.storeOverride(
            in: arguments("--store-path", "/tmp/uitest/Test.store")
        )
        #expect(override == .use(URL(fileURLWithPath: "/tmp/uitest/Test.store")))
    }

    @Test("Equals form")
    func parsesEqualsValue() {
        let override = LaunchArguments.storeOverride(
            in: arguments("--store-path=/tmp/uitest/Test.store")
        )
        #expect(override == .use(URL(fileURLWithPath: "/tmp/uitest/Test.store")))
    }

    @Test("Reads past arguments it does not recognise")
    func findsTheFlagAmongOthers() {
        let override = LaunchArguments.storeOverride(
            in: arguments("-NSDocumentRevisionsDebugMode", "YES", "--store-path", "/tmp/a.store")
        )
        #expect(override == .use(URL(fileURLWithPath: "/tmp/a.store")))
    }

    @Test("A path with spaces survives, since it arrives already split")
    func handlesSpacesInThePath() {
        let override = LaunchArguments.storeOverride(
            in: arguments("--store-path", "/tmp/ui test/Idle Tapper.store")
        )
        #expect(override == .use(URL(fileURLWithPath: "/tmp/ui test/Idle Tapper.store")))
    }

    @Test("Traversal is resolved rather than passed through")
    func standardisesThePath() {
        let override = LaunchArguments.storeOverride(in: arguments("--store-path", "/tmp/a/../b.store"))
        #expect(override == .use(URL(fileURLWithPath: "/tmp/b.store")))
    }

    // MARK: - Rejected, and why each must not become `.none`

    @Test("A trailing flag with no value is invalid, not absent")
    func trailingFlagIsInvalid() {
        // `.none` here would open the real store while the caller believed the
        // override had taken effect.
        guard case .invalid = LaunchArguments.storeOverride(in: arguments("--store-path")) else {
            Issue.record("A valueless --store-path must not read as absent")
            return
        }
    }

    @Test("A following flag is not swallowed as the value")
    func doesNotConsumeTheNextFlag() {
        guard case .invalid = LaunchArguments.storeOverride(
            in: arguments("--store-path", "--verbose")
        ) else {
            Issue.record("--verbose must not be treated as a store path")
            return
        }
    }

    @Test("An empty value is invalid")
    func emptyValueIsInvalid() {
        guard case .invalid = LaunchArguments.storeOverride(in: arguments("--store-path=")) else {
            Issue.record("An empty path must not read as absent")
            return
        }
    }

    @Test("A relative path is refused")
    func relativePathIsInvalid() {
        // An app launched by `open` has `/` as its working directory, so a
        // relative path resolves somewhere the caller did not choose.
        guard case .invalid = LaunchArguments.storeOverride(
            in: arguments("--store-path", "build/Test.store")
        ) else {
            Issue.record("A relative path must be refused, not resolved against an unknown cwd")
            return
        }
    }

    @Test("Every rejection explains itself")
    func rejectionsCarryAReason() {
        let rejected = [
            arguments("--store-path"),
            arguments("--store-path", "--verbose"),
            arguments("--store-path="),
            arguments("--store-path", "relative/path.store"),
        ]

        for argumentList in rejected {
            guard case .invalid(let reason) = LaunchArguments.storeOverride(in: argumentList) else {
                Issue.record("Expected \(argumentList) to be refused")
                continue
            }
            #expect(!reason.isEmpty)
        }
    }
}
