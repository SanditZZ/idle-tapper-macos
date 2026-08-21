//
//  MenuBarStylePicker.swift
//  Idle Tapper — Choosing what the status item shows
//
//  A radio group named the three styles but never showed them, so choosing
//  meant picking one and then looking up at the menu bar to find out what it
//  did. Each option here renders the thing it selects.
//

import SwiftUI
import Foundation

/// Selectable previews of the three menu bar styles.
struct MenuBarStylePicker: View {

    @Binding var selection: MenuBarDisplayStyle

    /// Sampled so the preview shows the user's own number rather than a made-up
    /// one, which is what makes it a preview rather than an illustration.
    let sampleCount: Int

    /// Today's goal, for the `goalProgress` preview. Zero when none is set, in
    /// which case that option previews the count — which is what it would
    /// actually show.
    let sampleGoal: Int

    var body: some View {
        // Four options no longer fit across a 260pt-wide row of previews, so
        // they wrap into a grid rather than being squeezed. `adaptive` keeps
        // two per row at the Settings window's minimum width and lets a wider
        // window use one row.
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: DesignTokens.Layout.menuBarStyleOptionMinWidth),
                    spacing: DesignTokens.Spacing.small
                )
            ],
            spacing: DesignTokens.Spacing.small
        ) {
            ForEach(MenuBarDisplayStyle.allCases) { style in
                StyleOption(
                    style: style,
                    sampleCount: sampleCount,
                    sampleGoal: sampleGoal,
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
    let sampleGoal: Int
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
    ///
    /// The title goes through the renderer itself rather than being formatted
    /// again here, so the preview cannot claim something the menu bar does not
    /// do — including the `goalProgress` fallback to a plain count when no goal
    /// is set. Padding is trimmed because a preview is centred rather than
    /// pinned to a fixed field.
    private var preview: some View {
        HStack(spacing: DesignTokens.Spacing.extraSmall) {
            if style.showsIcon {
                Image(systemName: StatusItemRenderer.symbolName)
                    .font(.system(size: DesignTokens.Icons.small))
            }
            if style.showsCount {
                Text(
                    StatusItemRenderer
                        .title(for: sampleCount, style: style, goal: sampleGoal)
                        .trimmingCharacters(in: .whitespaces)
                )
                .font(DesignTokens.Typography.monospacedDigitsSmall)
            }
        }
        .foregroundStyle(AppColors.textPrimary)
        .accessibilityHidden(true)
    }
}
