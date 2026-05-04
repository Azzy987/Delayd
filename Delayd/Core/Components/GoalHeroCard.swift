import SwiftUI

struct GoalHeroCard: View {
    let category: GoalCategory
    let goalName: String
    let currentAmount: String
    let targetAmount: String
    let progress: CGFloat
    let daysRemaining: Int
    let status: Status

    @ScaledMetric(relativeTo: .largeTitle) private var amountFontSize: CGFloat = 36
    @ScaledMetric(relativeTo: .body) private var goalFontSize: CGFloat = 20
    @ScaledMetric(relativeTo: .callout) private var targetFontSize: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            topRow
            amountBlock
            progressBlock
            bottomRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .delaydHeroCard()
        .accessibilityElement(children: .combine)
    }

    private var topRow: some View {
        HStack(spacing: AppSpacing.md) {
            GoalCategoryIcon(category: category, style: .hero)

            Text(goalName)
                .font(.system(size: goalFontSize, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            Spacer(minLength: AppSpacing.sm)

            Image(systemName: "chevron.right")
                .font(.callout.weight(.semibold))
                .opacity(0.75)
        }
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(currentAmount)
                .font(.system(size: amountFontSize, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("of \(targetAmount)")
                .font(.system(size: targetFontSize, weight: .regular, design: .monospaced))
                .opacity(0.70)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.top, AppSpacing.xs)
    }

    private var progressBlock: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.25))

                Capsule()
                    .fill(.white)
                    .frame(width: proxy.size.width * clampedProgress)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Goal progress")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent")
    }

    private var bottomRow: some View {
        HStack(spacing: AppSpacing.md) {
            Text("\(daysRemaining) days remaining")
                .font(AppTypography.callout)
                .opacity(0.70)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: AppSpacing.sm)

            Text(status.title)
                .font(AppTypography.captionMedium)
                .foregroundStyle(status.foregroundColor)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(status.backgroundColor, in: Capsule())
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private var clampedProgress: CGFloat {
        min(max(progress, 0), 1)
    }
}

extension GoalHeroCard {
    enum Status: Equatable {
        case onPace
        case delayed(days: Int)

        var title: String {
            switch self {
            case .onPace:
                "On pace"
            case .delayed(let days):
                "Delayed by \(days) days"
            }
        }

        var foregroundColor: Color {
            switch self {
            case .onPace:
                AppColors.positive
            case .delayed:
                AppColors.warning
            }
        }

        var backgroundColor: Color {
            switch self {
            case .onPace:
                AppColors.softPositiveBackground
            case .delayed:
                AppColors.softWarningBackground
            }
        }
    }

    static func mockOnPace() -> GoalHeroCard {
        GoalHeroCard(
            category: .travel,
            goalName: "Bali trip",
            currentAmount: "₹42,000",
            targetAmount: "₹1,20,000",
            progress: 0.35,
            daysRemaining: 128,
            status: .onPace
        )
    }

    static func mockDelayed() -> GoalHeroCard {
        GoalHeroCard(
            category: .vacation,
            goalName: "Japan spring escape",
            currentAmount: "₹78,500",
            targetAmount: "₹2,40,000",
            progress: 0.28,
            daysRemaining: 214,
            status: .delayed(days: 9)
        )
    }

    static func mockEdgeCase() -> GoalHeroCard {
        GoalHeroCard(
            category: .home,
            goalName: "A very long dream name that still needs to feel premium",
            currentAmount: "₹12,34,567",
            targetAmount: "₹45,00,000",
            progress: 0.82,
            daysRemaining: 1_204,
            status: .delayed(days: 42)
        )
    }
}

private struct GoalHeroCardPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            GoalHeroCard.mockOnPace()
            GoalHeroCard.mockDelayed()
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    GoalHeroCardPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    GoalHeroCard.mockEdgeCase()
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    GoalHeroCardPreviewGroup()
        .preferredColorScheme(.dark)
}
