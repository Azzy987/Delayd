import SwiftUI

struct DelayedImpactCard: View {
    let amountSpent: String
    let goalName: String
    let delayText: String
    let contextText: String

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var amountFontSize: CGFloat = 56
    @ScaledMetric(relativeTo: .largeTitle) private var delayFontSize: CGFloat = 48

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text(amountSpent)
                .font(.system(size: amountFontSize, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            VStack(spacing: AppSpacing.sm) {
                Text("delayed your")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                Text(goalName)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)

                Text("by")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            }

            Text(delayText)
                .font(.system(size: delayFontSize, weight: .bold, design: .default))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .gradientText()
                .padding(.top, AppSpacing.xs)

            Text(contextText)
                .font(AppTypography.callout)
                .italic()
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.top, AppSpacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.xxl)
        .background(cardBackground)
        .delaydShadow()
        .accessibilityElement(children: .combine)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppRadius.xl)
            .fill(AppColors.surface(for: colorScheme))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.xl)
                    .fill(AppGradients.heroGradient)
                    .opacity(0.08)
            }
    }
}

extension DelayedImpactCard {
    static func mock() -> DelayedImpactCard {
        DelayedImpactCard(
            amountSpent: "₹500",
            goalName: "Bali trip",
            delayText: "2 days",
            contextText: "That dinner moved your dream a little further away."
        )
    }

    static func mockEdgeCase() -> DelayedImpactCard {
        DelayedImpactCard(
            amountSpent: "₹12,345",
            goalName: "A very long dream name that still has to feel personal",
            delayText: "27 days",
            contextText: "A single spend can shift the date more than it looks on a receipt."
        )
    }

    static func mockSmallImpact() -> DelayedImpactCard {
        DelayedImpactCard(
            amountSpent: "₹99",
            goalName: "Gaming setup",
            delayText: "4 hours",
            contextText: "Small choices still move the timeline."
        )
    }
}

private struct DelayedImpactCardPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            DelayedImpactCard.mock()
            DelayedImpactCard.mockSmallImpact()
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    DelayedImpactCardPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    DelayedImpactCard.mockEdgeCase()
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    DelayedImpactCardPreviewGroup()
        .preferredColorScheme(.dark)
}
