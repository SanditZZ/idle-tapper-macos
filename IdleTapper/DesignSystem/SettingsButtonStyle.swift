//
//  SettingsButtonStyle.swift
//  Idle Tapper — Button appearance
//
//  The stock `.bordered` button draws a small system-radius capsule that sits
//  awkwardly next to 12px cards. This gives buttons the same corner language as
//  everything around them, and a hover state, which the stock style on macOS
//  does not provide for a bordered button in a non-focused window.
//

import SwiftUI

/// Consistent button appearance across the app.
struct SettingsButtonStyle: ButtonStyle {

    /// What the button is for. Chooses fill and label colour; the geometry is
    /// identical across all three so a row of mixed buttons stays aligned.
    enum Kind {
        /// The main action of its group.
        case primary
        /// Everything else.
        case secondary
        /// Irreversible actions. Red, and never the default.
        case destructive
    }

    var kind: Kind = .secondary

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, kind: kind)
    }

    /// A nested view so the style can hold hover state, which `makeBody` cannot.
    private struct StyledLabel: View {
        let configuration: Configuration
        let kind: Kind

        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(DesignTokens.Typography.body)
                .foregroundStyle(labelColor)
                .padding(.horizontal, DesignTokens.Spacing.medium)
                .padding(.vertical, DesignTokens.Spacing.small)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.control)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.control)
                        .strokeBorder(AppColors.cardBorder, lineWidth: kind == .secondary ? 0.5 : 0)
                )
                .opacity(isEnabled ? 1 : 0.45)
                .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control))
                .onHover { isHovering = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }

        /// Pressed reads deeper than hovered, so a press inside a hover is still
        /// a visible state change rather than nothing happening.
        private var fill: Color {
            switch kind {
            case .primary:
                guard isEnabled else { return AppColors.accent }
                if configuration.isPressed { return AppColors.accent.opacity(0.75) }
                if isHovering { return AppColors.accent.opacity(0.88) }
                return AppColors.accent

            case .secondary:
                guard isEnabled else { return AppColors.controlFill }
                if configuration.isPressed { return AppColors.controlFillPressed }
                if isHovering { return AppColors.controlFillHover }
                return AppColors.controlFill

            case .destructive:
                guard isEnabled else { return AppColors.destructiveFill }
                if configuration.isPressed { return AppColors.destructiveFillPressed }
                if isHovering { return AppColors.destructiveFillHover }
                return AppColors.destructiveFill
            }
        }

        private var labelColor: Color {
            switch kind {
            case .primary: AppColors.tapButtonLabel
            case .secondary: AppColors.textPrimary
            case .destructive: AppColors.error
            }
        }
    }
}

extension ButtonStyle where Self == SettingsButtonStyle {
    /// The main action of its group.
    static var settingsPrimary: SettingsButtonStyle { SettingsButtonStyle(kind: .primary) }

    /// The default for ordinary actions.
    static var settings: SettingsButtonStyle { SettingsButtonStyle(kind: .secondary) }

    /// Irreversible actions.
    static var settingsDestructive: SettingsButtonStyle { SettingsButtonStyle(kind: .destructive) }
}
