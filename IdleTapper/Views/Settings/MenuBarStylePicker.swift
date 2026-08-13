//
//  MenuBarStylePicker.swift
//  Idle Tapper — Choosing what the status item shows
//
//  A radio group named the three styles but never showed them, so choosing
//  meant picking one and then looking up at the menu bar to find out what it
//  did. Each option here renders the thing it selects.
//

import SwiftUI

/// Selectable previews of the three menu bar styles.
struct MenuBarStylePicker: View {

    @Binding var selection: MenuBarDisplayStyle

    /// Sampled so the preview shows the user's own number rather than a made-up
    /// one, which is what makes it a preview rather than an illustration.
    let sampleCount: Int

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            ForEach(MenuBarDisplayStyle.allCases) { style in
                StyleOption(
                    style: style,
                    sampleCount: sampleCount,
                    isSelected: style == selection,
                    select: { selection = style }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Show in menu bar")
    }
}

private struct StyleOption: View {

    let style: MenuBarDisplayStyle
    let sampleCount: Int
    let isSelected: Bool
    let select: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            VStack(spacing: DesignTokens.Spacing.small) {
                preview
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                            .fill(AppColors.controlFill)
                    )

                Text(style.displayName)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
            }
            .padding(DesignTokens.Spacing.small)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control)
                    .fill(isSelected ? AppColors.selectionFill : (isHovering ? AppColors.hoverFill : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control)
                    .strokeBorder(
                        isSelected ? AppColors.accent : AppColors.cardBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .accessibilityLabel(style.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Mirrors what `StatusItemRenderer` actually draws for this style.
    private var preview: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            if style.showsIcon {
                Image(systemName: StatusItemRenderer.symbolName)
                    .font(.system(size: DesignTokens.Icons.small))
            }
            if style.showsCount {
                Text(sampleCount.formatted(.number))
                    .font(DesignTokens.Typography.monospacedDigitsSmall)
            }
        }
        .foregroundStyle(AppColors.textPrimary)
        .accessibilityHidden(true)
    }
}
