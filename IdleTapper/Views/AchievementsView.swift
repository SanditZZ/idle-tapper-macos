//
//  AchievementsView.swift
//  Idle Tapper — Achievements window
//
//  The full catalog, each entry showing its unlocked date or progress toward
//  it. `tracker.achievementProgress` already carries locked/unlocked state
//  and current/target figures in catalog order, so this view only renders.
//

import SwiftUI

struct AchievementsView: View {

    @Bindable var tracker: TapTracker

    private let columns = [
        GridItem(.flexible(), spacing: DesignTokens.Spacing.cardSpacing),
        GridItem(.flexible(), spacing: DesignTokens.Spacing.cardSpacing),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.cardSpacing) {
                header
                grid
            }
            .padding(.horizontal, DesignTokens.Spacing.contentPadding)
            .padding(.bottom, DesignTokens.Spacing.contentPadding)
            // The window draws under its title bar so the background runs the
            // full height; the header has to start below the traffic lights.
            .padding(.top, DesignTokens.Layout.titleBarInset)
        }
        .background(AppColors.windowSurface)
        .frame(
            minWidth: DesignTokens.Layout.achievementsWindowMinSize.width,
            idealWidth: DesignTokens.Layout.achievementsWindowSize.width,
            minHeight: DesignTokens.Layout.achievementsWindowMinSize.height,
            idealHeight: DesignTokens.Layout.achievementsWindowSize.height
        )
    }

    // MARK: - Sections

    private var header: some View {
        SettingsPageHeader(
            title: "Achievements",
            subtitle: "\(unlockedCount) of \(tracker.achievementProgress.count) unlocked",
            systemImage: "trophy.fill"
        )
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.cardSpacing) {
            // Zipped rather than looked up by id: `AchievementCalculator.progress`
            // already maps the catalog in order, so pairing positionally avoids a
            // lookup (and a force-unwrap) that could only ever fail if the two
            // ever drifted apart.
            ForEach(Array(zip(AchievementCatalog.all, tracker.achievementProgress)), id: \.0.id) { definition, progress in
                AchievementCard(definition: definition, progress: progress)
            }
        }
    }

    // MARK: - Calculations

    private var unlockedCount: Int {
        tracker.achievementProgress.filter(\.isUnlocked).count
    }
}

/// One catalog entry: icon, title, detail, and its unlocked/locked state.
private struct AchievementCard: View {

    let definition: AchievementDefinition
    let progress: AchievementProgress

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(definition.title)
                        .font(DesignTokens.Typography.bodyMedium)
                        .foregroundStyle(progress.isUnlocked ? AppColors.textPrimary : AppColors.textSecondary)
                    Text(definition.detail)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if progress.isUnlocked {
                Label("Unlocked", systemImage: "checkmark.circle.fill")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.success)
            } else {
                ProgressView(value: progress.fraction)
                    .tint(AppColors.accent)
                Text("\(progress.current.formatted()) / \(progress.target.formatted())")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: DesignTokens.Spacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(definition.title)
        .accessibilityValue(
            progress.isUnlocked
                ? "Unlocked"
                : "Locked, \(progress.current.formatted()) of \(progress.target.formatted())"
        )
    }

    private var icon: some View {
        Image(systemName: definition.systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(progress.isUnlocked ? AppColors.accentOnText : AppColors.textTertiary)
            .frame(width: 28, height: 28)
            .background(
                Circle().fill(
                    progress.isUnlocked
                        ? AppColors.tint(AppColors.accent)
                        : AppColors.tint(AppColors.textTertiary, opacity: 0.08)
                )
            )
            .accessibilityHidden(true)
    }
}
