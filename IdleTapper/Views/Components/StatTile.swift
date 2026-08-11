//
//  StatTile.swift
//  Idle Tapper — Components
//
//  A labelled statistic. Used in a row beneath the tap button and in the
//  history window header.
//

import SwiftUI

/// An uppercase label above a value, optionally with a leading SF Symbol.
struct StatTile: View {

    let label: String
    let value: String

    /// SF Symbol shown beside the value.
    var systemImage: String?

    /// Tint applied to the icon. The value itself stays primary for legibility.
    var tint: Color = AppColors.textSecondary

    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label.uppercased())
                .font(DesignTokens.Typography.statLabel)
                .foregroundStyle(AppColors.textTertiary)
                .lineLimit(1)

            HStack(spacing: DesignTokens.Spacing.extraSmall) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: DesignTokens.Icons.tiny, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Text(value)
                    .font(DesignTokens.Typography.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

#Preview {
    HStack(spacing: DesignTokens.Spacing.medium) {
        StatTile(label: "All time", value: "12,480", systemImage: "sum")
        StatTile(label: "Best day", value: "1,204", systemImage: "trophy.fill", tint: AppColors.warning)
        StatTile(label: "Streak", value: "6d", systemImage: "flame.fill", tint: AppColors.error)
    }
    .padding()
    .frame(width: DesignTokens.Layout.popoverWidth)
}
