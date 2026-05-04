import SwiftUI

struct SmartInsightCard: View {
    let insightText: String
    var trailingTitle: String = "View"
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .delaydInsightBanner()
        .accessibilityElement(children: .combine)
    }

    private var content: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.insightBannerAccent)
                .frame(width: 28, height: 28)

            Text(insightText)
                .font(.system(.callout, design: .default, weight: .medium))
                .foregroundStyle(AppColors.insightBannerText)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: AppSpacing.sm)

            HStack(spacing: AppSpacing.xs) {
                Text(trailingTitle)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(AppColors.insightBannerText.opacity(0.82))
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: AppRadius.md))
        }
    }
}

extension SmartInsightCard {
    static let sampleInsights = [
        "Skipping this 4x/month would put Bali 8 days closer.",
        "This spend used 12% of your weekly delay budget.",
        "Your Japan spring escape just slipped to May 14."
    ]

    static func mock(index: Int = 0) -> SmartInsightCard {
        SmartInsightCard(insightText: sampleInsights[index % sampleInsights.count])
    }

    static func mockEdgeCase() -> SmartInsightCard {
        SmartInsightCard(insightText: "Three small impulse buys this week have moved your dream further than one big purchase would have.")
    }
}

private struct SmartInsightCardPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            ForEach(Array(SmartInsightCard.sampleInsights.enumerated()), id: \.offset) { index, _ in
                SmartInsightCard.mock(index: index)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    SmartInsightCardPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    SmartInsightCard.mockEdgeCase()
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    SmartInsightCardPreviewGroup()
        .preferredColorScheme(.dark)
}
