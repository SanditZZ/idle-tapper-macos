//
//  SettingsPage.swift
//  Idle Tapper — Scaffold shared by every settings page
//
//  Header, padding and scrolling are decided here once. A page that laid these
//  out itself would drift from its neighbours, and the content jumping by a few
//  points as the sidebar selection changes is exactly the kind of small wrong
//  thing that makes a window feel unfinished.
//

import SwiftUI

/// A settings page: title block, then a stack of cards, scrolling if needed.
struct SettingsPage<Content: View>: View {

    let section: SettingsSection
    @ViewBuilder let content: Content

    init(section: SettingsSection, @ViewBuilder content: () -> Content) {
        self.section = section
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.cardSpacing) {
                SettingsPageHeader(
                    title: section.title,
                    subtitle: section.subtitle,
                    systemImage: section.systemImage
                )
                // A little more air under the header than between the cards, so
                // the title reads as the page's own rather than as the first
                // card's.
                .padding(.bottom, DesignTokens.Spacing.extraSmall)

                content
            }
            .padding(.horizontal, DesignTokens.Spacing.contentPadding)
            .padding(.bottom, DesignTokens.Spacing.contentPadding)
            // Matches the sidebar's own top inset, so the page title and the
            // first sidebar row sit on the same line rather than a few points
            // apart — the window draws under its title bar.
            .padding(.top, DesignTokens.Layout.titleBarInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Every page scrolls, whether or not its content currently overflows.
        // A window that clips silently is how the old Settings lost its Data
        // section, and a page that only gains a scroller once it is too late
        // has the same failure with extra steps.
        .scrollBounceBehavior(.basedOnSize)
    }
}
