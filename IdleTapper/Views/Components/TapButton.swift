//
//  TapButton.swift
//  Idle Tapper — Components
//
//  The game's core affordance: a large rounded button that counts a tap on
//  press-down rather than on click-up, so rapid tapping feels immediate.
//
//  The visual press is held for a minimum duration rather than mirroring the
//  gesture exactly — see `PressAnimationTiming` for why a soft trackpad tap
//  would otherwise produce no visible feedback at all.
//

import SwiftUI

/// A large, rounded, pressable button.
struct TapButton: View {

    /// Called once per tap, on press-down.
    let action: () -> Void

    /// Label shown in the centre of the button.
    var title: String = "TAP"

    /// Today's total, announced as the button's value.
    ///
    /// Deliberately the *value* rather than part of the label. VoiceOver
    /// re-reads the value of the element it is focused on when that value
    /// changes, so activating the button says the new total — which is the whole
    /// feedback loop of the app, and the one thing a listener otherwise has no
    /// way to perceive. Folded into the label it would be read once on focus and
    /// then be wrong for every tap after.
    var todayCount: Int?

    var height: CGFloat = DesignTokens.Layout.tapButtonHeight

    /// Drives the animation. Not the same as the physical press: it is held for
    /// at least `PressAnimationTiming.minimumVisibleDuration`.
    @State private var isPressed = false

    /// Whether the mouse button is actually down right now. Kept separate from
    /// `isPressed` so a new tap is never swallowed while the previous one is
    /// still finishing its animation.
    @State private var isPhysicallyDown = false

    /// When the current visual press began.
    @State private var pressStartedAt: Date?

    /// Pending delayed release, cancelled if another tap arrives first.
    @State private var releaseTask: Task<Void, Never>?

    // Split from `body` only because the whole chain in one expression exceeds
    // what the type-checker will solve in reasonable time.
    var body: some View {
        surface
            .frame(height: height)
            .scaleEffect(isPressed ? DesignTokens.Motion.tapPressedScale : 1)
            .animation(DesignTokens.Motion.tapPress, value: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.tapButton, style: .continuous))
            .gesture(pressGesture)
            .onDisappear { releaseTask?.cancel() }
            .accessibilityElement()
            .accessibilityLabel("Tap")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint("Adds one tap to today's total")
            .accessibilityAddTraits(.isButton)
            // The press is driven by a `DragGesture`, which VoiceOver cannot
            // perform: without this the button is reachable and correctly
            // announced but genuinely cannot be activated, which is a worse
            // failure than being unlabelled.
            .accessibilityAction { action() }
    }

    private var surface: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.tapButton, style: .continuous)
            .fill(isPressed ? AppColors.tapButtonPressedFill : AppColors.tapButtonFill)
            .overlay {
                // A soft inner highlight gives the surface some depth without
                // needing an image asset.
                RoundedRectangle(cornerRadius: DesignTokens.Radius.tapButton, style: .continuous)
                    .strokeBorder(Color.white.opacity(isPressed ? 0.32 : 0.18), lineWidth: 1)
            }
            .overlay {
                Text(title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(AppColors.tapButtonLabel)
                    .scaleEffect(isPressed ? 0.96 : 1)
            }
    }

    private var accessibilityValue: String {
        guard let todayCount else { return "" }
        return "\(todayCount.formatted()) today"
    }

    // MARK: - Gesture

    /// Counts on press-down and releases the visual press once it has been
    /// shown for long enough.
    ///
    /// `minimumDistance: 0` makes the gesture fire the instant the mouse goes
    /// down; a plain `Button` would wait for mouse-up and would drop taps
    /// during fast clicking.
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in beginPress() }
            .onEnded { _ in endPress() }
    }

    // MARK: - Press Handling

    private func beginPress() {
        // `onChanged` fires repeatedly while the mouse moves; only the first
        // one is a new tap.
        guard !isPhysicallyDown else { return }
        isPhysicallyDown = true

        // A tap arriving while the previous release is still pending takes over
        // the animation rather than being ignored.
        releaseTask?.cancel()
        releaseTask = nil

        pressStartedAt = Date()
        isPressed = true

        action()
    }

    private func endPress() {
        isPhysicallyDown = false

        let hold = pressStartedAt.map {
            PressAnimationTiming.remainingHold(pressedAt: $0, now: Date())
        } ?? .zero

        guard hold > .zero else {
            release()
            return
        }

        // The press was too brief to see — hold the pressed state a little
        // longer so a soft trackpad tap animates like a firm one.
        releaseTask = Task { @MainActor in
            try? await Task.sleep(for: hold)
            guard !Task.isCancelled else { return }
            release()
        }
    }

    private func release() {
        // Ignore a stale release that lost the race with a newer press.
        guard !isPhysicallyDown else { return }
        isPressed = false
        pressStartedAt = nil
        releaseTask = nil
    }
}

#Preview {
    TapButton(action: {})
        .padding()
        .frame(width: DesignTokens.Layout.popoverWidth)
}
