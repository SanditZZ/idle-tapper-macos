//
//  CardModifier.swift
//  Idle Tapper — Reusable view styling
//
//  Shared container styles so cards look identical everywhere rather than being
//  re-derived per view.
//

import SwiftUI

/// Standard card appearance: padded, translucent fill, hairline border.
struct CardModifier: ViewModifier {
    var padding: CGFloat = DesignTokens.Spacing.cardPadding
    var radius: CGFloat = DesignTokens.Radius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(AppColors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(AppColors.cardBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    /// Apply the standard card styling.
    func appCard(
        padding: CGFloat = DesignTokens.Spacing.cardPadding,
        radius: CGFloat = DesignTokens.Radius.card
    ) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}
