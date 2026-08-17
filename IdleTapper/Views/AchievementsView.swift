//
//  AchievementsView.swift
//  Idle Tapper — Achievements window
//
//  The full catalog, split into tier sections, each entry showing its unlock
//  date or its progress toward one. `tracker.achievementProgress` already
//  carries the unlock date, the tier and the current/target figures in catalog
//  order, so this view only groups and renders.
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
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.section) {
                header
                ForEach(groups) { group in
                    tierSection(group)
                }
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

    private func tierSection(_ group: AchievementTierGroup) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            tierHeading(group)
            LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.cardSpacing) {
                // Looked up by id rather than zipped positionally against the
                // catalog, which is what this used to do: grouping reorders
                // the entries into sections, so their positions no longer line
                // up with `AchievementCatalog.all`.
                ForEach(group.entries) { progress in
                    if let definition = AchievementCatalog.byID[progress.id] {
                        AchievementCard(definition: definition, progress: progress)
                    }
                }
            }
        }
    }

    private func tierHeading(_ group: AchievementTierGroup) -> some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Image(systemName: "circle.fill")
                .font(DesignTokens.Typography.tiny)
                .foregroundStyle(AppColors.tier(group.tier))
                .accessibilityHidden(true)

            Text(group.tier.title)
                .font(DesignTokens.Typography.sectionLabel)
                .foregroundStyle(AppColors.tier(group.tier))

            Spacer(minLength: DesignTokens.Spacing.small)

            Text("\(group.unlockedCount) of \(group.entries.count)")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.tier.title) tier")
        .accessibilityValue("\(group.unlockedCount) of \(group.entries.count) unlocked")
    }

    // MARK: - Calculations

    private var groups: [AchievementTierGroup] {
        AchievementCalculator.grouped(tracker.achievementProgress)
    }

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
                        // Space for both lines is held whether or not the
                        // sentence needs them — see `achievementDetailLines`.
                        .lineLimit(DesignTokens.Layout.achievementDetailLines, reservesSpace: true)
                }
                Spacer(minLength: 0)
            }

            footer
        }
        // Every card is the same height by construction: two reserved detail
        // lines above a reserved footer. `maxHeight` then makes a card fill its
        // row, so nothing can disagree even if a title ever wraps.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appCard(padding: DesignTokens.Spacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(definition.title)
        .accessibilityValue(accessibilityValue)
    }

    /// The unlock date, or the progress toward it, in a zone of fixed height so
    /// the two states cannot give a card two different sizes.
    @ViewBuilder
    private var footer: some View {
        Group {
            if let unlockedAt = progress.unlockedAt {
                Label(unlockedLabel(unlockedAt), systemImage: "checkmark.circle.fill")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(AppColors.success)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.extraSmall) {
                    ProgressView(value: progress.fraction)
                        .tint(AppColors.accent)
                    Text("\(progress.current.formatted()) / \(progress.target.formatted())")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: DesignTokens.Layout.achievementFooterHeight,
            maxHeight: DesignTokens.Layout.achievementFooterHeight,
            alignment: .topLeading
        )
    }

    private var icon: some View {
        Image(systemName: definition.systemImage)
            .font(.system(size: 18, weight: .semibold))
            // Unlocked badges take their tier's colour rather than the accent,
            // so the tier a card belongs to is legible from the card itself
            // and not only from the heading it happens to sit under.
            .foregroundStyle(progress.isUnlocked ? AppColors.tier(definition.tier) : AppColors.textTertiary)
            .frame(width: 28, height: 28)
            .background(
                Circle().fill(
                    progress.isUnlocked
                        ? AppColors.tint(AppColors.tier(definition.tier))
                        : AppColors.tint(AppColors.textTertiary, opacity: 0.08)
                )
            )
            .accessibilityHidden(true)
    }

    // MARK: - Calculations

    /// Dates only — an unlock time to the minute is precision nobody asked
    /// for, and it would wrap the label onto a second line in a card this
    /// narrow.
    private func unlockedLabel(_ date: Date) -> String {
        "Unlocked \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    private var accessibilityValue: String {
        if let unlockedAt = progress.unlockedAt {
            return unlockedLabel(unlockedAt)
        }
        return "Locked, \(progress.current.formatted()) of \(progress.target.formatted())"
    }
}
