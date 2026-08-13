//
//  SettingsCard.swift
//  Idle Tapper — Grouping container for settings controls
//
//  A card carries its own title and explanatory footer so a page is a stack of
//  cards rather than a stack of loose headings, dividers and controls that each
//  view spaces slightly differently.
//

import SwiftUI

/// A titled group of related controls.
struct SettingsCard<Content: View>: View {

    let title: String?
    let subtitle: String?
    /// Explanation shown under the controls, in the card's quietest style.
    let footer: String?
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.controlCaption) {
                    if let title {
                        Text(title)
                            .font(DesignTokens.Typography.cardTitle)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(AppColors.textTertiary)
                            // Without this a long subtitle truncates to one
                            // line instead of wrapping.
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
                content
            }

            if let footer {
                Text(footer)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // Fill the width before the card styling is applied, or each card hugs
        // its own content and a page renders with a ragged right edge.
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

/// The title block at the top of a settings page.
struct SettingsPageHeader: View {

    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(AppColors.accentOnText)
                // A fixed frame keeps the titles of every page aligned with each
                // other, which SF Symbols' varying glyph widths otherwise break.
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.pageTitle)
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(DesignTokens.Typography.pageSubtitle)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
