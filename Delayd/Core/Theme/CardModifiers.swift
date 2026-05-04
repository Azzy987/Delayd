import SwiftUI

private struct DelaydCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shadow = AppShadows.card(for: colorScheme)

        content
            .padding(.horizontal, AppSpacing.cardHorizontalPadding)
            .padding(.vertical, AppSpacing.cardVerticalPadding)
            .background(AppColors.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .shadow(color: shadow.color, radius: shadow.blur, x: shadow.x, y: shadow.y)
    }
}

private struct DelaydHeroCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shadow = AppShadows.heroCard(for: colorScheme)

        content
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.heroCardPadding)
            .padding(.vertical, AppSpacing.heroCardPadding)
            .background(AppGradients.heroGradient, in: RoundedRectangle(cornerRadius: AppRadius.xl))
            .shadow(color: shadow.color, radius: shadow.blur, x: shadow.x, y: shadow.y)
    }
}

private struct DelaydSectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.sm)
    }
}

private struct DelaydInsightBannerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AppTypography.bodyMedium)
            .foregroundStyle(AppColors.insightBannerText)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.insightBannerBackground, in: RoundedRectangle(cornerRadius: AppRadius.xl))
            .shadow(color: AppColors.insightBannerGlow, radius: 20, x: 0, y: 8)
    }
}

extension View {
    func delaydCard() -> some View {
        modifier(DelaydCardModifier())
    }

    func delaydHeroCard() -> some View {
        modifier(DelaydHeroCardModifier())
    }

    func delaydSection() -> some View {
        modifier(DelaydSectionModifier())
    }

    func delaydInsightBanner() -> some View {
        modifier(DelaydInsightBannerModifier())
    }
}

private struct CardModifiersPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Bali trip")
                        .font(AppTypography.title)
                    Text("₹500 delayed this dream by 2 days")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .delaydCard()

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("48 days")
                        .font(AppTypography.impactNumber)
                    Text("Closer when spending stays aligned")
                        .font(AppTypography.bodyMedium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .delaydHeroCard()

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Recent impacts")
                        .font(AppTypography.sectionHeader)
                    Text("A section keeps related dream-delay content breathing.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }
                .delaydSection()

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "sparkle")
                    Text("Skipping this 4x/month puts Bali 8 days closer")
                }
                .delaydInsightBanner()
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Card Modifiers Light") {
    CardModifiersPreview()
        .preferredColorScheme(.light)
}

#Preview("Card Modifiers Dark") {
    CardModifiersPreview()
        .preferredColorScheme(.dark)
}
