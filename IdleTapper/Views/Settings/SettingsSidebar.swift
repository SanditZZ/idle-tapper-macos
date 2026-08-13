//
//  SettingsSidebar.swift
//  Idle Tapper — Settings navigation
//
//  A hand-rolled list rather than SwiftUI's `List`: `List` on macOS brings its
//  own inset, its own selection colour and its own row height, none of which
//  match the tokens the rest of the window is built from, and all of which are
//  awkward to override.
//

import SwiftUI

/// The navigation list down the left of the Settings window.
struct SettingsSidebar: View {

    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
                ForEach(SettingsSection.allCases) { section in
                    SidebarRow(
                        section: section,
                        isSelected: section == selection,
                        select: { selection = section }
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.medium)
            // The window draws under its title bar so this material runs the
            // full height, which means the first row has to start below the
            // traffic lights rather than underneath them.
            .padding(.top, DesignTokens.Layout.titleBarInset)

            // No version footer here. It restated what About says canonically,
            // and on the About page the same string appeared twice at once —
            // in the sidebar and in the card beside the app icon. macOS's own
            // Settings keeps its sidebar to navigation for the same reason.
            Spacer(minLength: DesignTokens.Spacing.large)
        }
        .frame(width: DesignTokens.Layout.settingsSidebarWidth, alignment: .leading)
        .background(VisualEffectView(material: .sidebar))
    }
}

/// One navigation row.
private struct SidebarRow: View {

    let section: SettingsSection
    let isSelected: Bool
    let select: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: DesignTokens.Spacing.iconText) {
                Image(systemName: section.systemImage)
                    .font(.system(size: DesignTokens.Icons.standard))
                    // A fixed frame keeps the labels aligned regardless of how
                    // wide each symbol's glyph happens to be.
                    .frame(width: DesignTokens.Spacing.iconFrame, alignment: .center)
                    .foregroundStyle(isSelected ? AppColors.accentOnText : AppColors.textSecondary)

                Text(section.title)
                    .font(DesignTokens.Typography.sidebarItem)
                    .foregroundStyle(isSelected ? AppColors.textPrimary : AppColors.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.small)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control)
                    .fill(fill)
            )
            // Without this the row only responds where the icon and text are,
            // leaving the padding around them dead to the pointer.
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var fill: Color {
        if isSelected { return AppColors.selectionFill }
        if isHovering { return AppColors.hoverFill }
        return .clear
    }
}
