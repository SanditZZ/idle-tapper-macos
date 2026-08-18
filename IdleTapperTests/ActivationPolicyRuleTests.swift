//
//  ActivationPolicyRuleTests.swift
//  IdleTapperTests
//

import Testing
import AppKit
@testable import IdleTapper

@Suite("Activation policy")
struct ActivationPolicyRuleTests {

    @Test("With no window open the app stays an accessory")
    func noWindowsIsAccessory() {
        #expect(ActivationPolicyRule.policy(openWindowCount: 0) == .accessory)
        #expect(!ActivationPolicyRule.appearsInSwitcher(openWindowCount: 0))
    }

    @Test("One open window is enough to join the switcher")
    func oneWindowIsRegular() {
        #expect(ActivationPolicyRule.policy(openWindowCount: 1) == .regular)
        #expect(ActivationPolicyRule.appearsInSwitcher(openWindowCount: 1))
    }

    /// Closing one of several windows must not send the app back to accessory
    /// while the others are still on screen — that would drop it out of the
    /// switcher with its own windows still open.
    @Test("The app stays regular while any window remains")
    func severalWindowsStayRegular() {
        #expect(ActivationPolicyRule.policy(openWindowCount: 2) == .regular)
        #expect(ActivationPolicyRule.policy(openWindowCount: 3) == .regular)
    }

    /// A count can only go negative through a bookkeeping mistake. Degrading to
    /// the app's normal state is the safe direction: the opposite would strand a
    /// Dock icon that no window is left to remove.
    @Test("A negative count degrades to accessory rather than trapping")
    func negativeCountIsAccessory() {
        #expect(ActivationPolicyRule.policy(openWindowCount: -1) == .accessory)
    }
}
