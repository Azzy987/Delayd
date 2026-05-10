import SwiftUI

struct GoalCard: View {
    let category: GoalCategory
    let goalName: String
    let currentAmount: String
    let targetAmount: String
    let progress: CGFloat
    let percentageText: String
    let warningText: String?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                GoalCategoryIcon(category: category)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(goalName)
                                .font(AppTypography.title)
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)

                            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                                Text(currentAmount)
                                    .font(.system(.body, design: .monospaced, weight: .bold))
                                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                                Text("of \(targetAmount)")
                                    .font(.system(.caption, design: .monospaced, weight: .regular))
                                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        }

                        Spacer(minLength: AppSpacing.sm)

                        Text(percentageText)
                            .font(AppTypography.captionMedium)
                            .foregroundStyle(category.accentColor)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(category.backgroundColor, in: Capsule())
                            .lineLimit(1)
                    }

                    progressBar
                }
            }

            if let warningText {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.caption)
                    Text(warningText)
                        .font(AppTypography.captionMedium)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(AppColors.warning)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.softWarningBackground, in: RoundedRectangle(cornerRadius: AppRadius.md))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .delaydCard()
        .accessibilityElement(children: .combine)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let safeProgress = LayoutGuard.unit(clampedProgress, name: "GoalCard.progress")
            let safeWidth = LayoutGuard.dimension(proxy.size.width * safeProgress, name: "GoalCard.progressWidth")
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(category.backgroundColor)

                Capsule()
                    .fill(category.accentColor)
                    .frame(width: safeWidth)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Goal progress")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent")
    }

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }
}

extension GoalCard {
    static func mock() -> GoalCard {
        GoalCard(
            category: .vehicle,
            goalName: "Save for a car",
            currentAmount: "₹2,500",
            targetAmount: "₹7,500",
            progress: 0.33,
            percentageText: "33%",
            warningText: nil
        )
    }

    static func mockBehindSchedule() -> GoalCard {
        GoalCard(
            category: .travel,
            goalName: "House by the sea",
            currentAmount: "₹8,750",
            targetAmount: "₹1,75,000",
            progress: 0.30,
            percentageText: "30%",
            warningText: "You're 30% behind schedule"
        )
    }

    static func mockEdgeCase() -> GoalCard {
        GoalCard(
            category: .education,
            goalName: "Postgraduate degree and relocation fund with a very long title",
            currentAmount: "₹12,34,567",
            targetAmount: "₹45,00,000",
            progress: 0.74,
            percentageText: "74%",
            warningText: "You're 12% behind schedule after the latest delay impact"
        )
    }
}

private struct GoalCardPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            GoalCard.mock()
            GoalCard.mockBehindSchedule()
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    GoalCardPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    GoalCard.mockEdgeCase()
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    GoalCardPreviewGroup()
        .preferredColorScheme(.dark)
}
