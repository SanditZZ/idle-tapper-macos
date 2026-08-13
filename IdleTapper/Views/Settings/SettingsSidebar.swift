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

    /// Shown under the list, the way most macOS settings windows identify the app.
    let appVersion: String

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

            Spacer(minLength: DesignTokens.Spacing.large)

            VStack(alignment: .leading, spacing: 2) {
                Text("Idle Tapper")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(appVersion)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, DesignTokens.Spacing.large)
            .padding(.bottom, DesignTokens.Spacing.large)
            .accessibilityElement(children: .combine)
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
