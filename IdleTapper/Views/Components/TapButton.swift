//
//  TapButton.swift
//  Idle Tapper — Components
//
//  The game's core affordance: a large rounded button that counts a tap on
//  press-down rather than on click-up, so rapid tapping feels immediate.
//

import SwiftUI

/// A large, rounded, pressable button.
struct TapButton: View {

    /// Called once per tap, on press-down.
    let action: () -> Void

    /// Label shown in the centre of the button.
    var title: String = "TAP"

    var height: CGFloat = DesignTokens.Layout.tapButtonHeight

    @State private var isPressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.tapButton, style: .continuous)
            .fill(isPressed ? AppColors.tapButtonPressedFill : AppColors.tapButtonFill)
            .overlay {
                // A soft inner highlight gives the surface some depth without
                // needing an image asset.
                RoundedRectangle(cornerRadius: DesignTokens.Radius.tapButton, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            }
            .overlay {
                Text(title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .kerning(2)
                    .foregroundStyle(AppColors.tapButtonLabel)
            }
            .frame(height: height)
            .scaleEffect(isPressed ? DesignTokens.Motion.tapPressedScale : 1)
            .animation(DesignTokens.Motion.tapPress, value: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.tapButton, style: .continuous))
            .gesture(pressGesture)
            .accessibilityElement()
            .accessibilityLabel("Tap")
            .accessibilityHint("Adds one tap to today's total")
            .accessibilityAddTraits(.isButton)
    }

    /// Counts on press-down and holds the pressed state until release.
    ///
    /// `minimumDistance: 0` makes the gesture fire the instant the mouse goes
    /// down; a plain `Button` would wait for mouse-up and would drop taps
    /// during fast clicking.
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressed else { return }
                isPressed = true
                action()
            }
            .onEnded { _ in
                isPressed = false
            }
    }
}

#Preview {
    TapButton(action: {})
        .padding()
        .frame(width: DesignTokens.Layout.popoverWidth)
}
