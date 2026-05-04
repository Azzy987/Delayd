import SwiftUI

struct EmptyStateCard: View {
    let systemImage: String
    let assetImageName: String?
    let title: String
    let description: String
    let ctaTitle: String?
    let action: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    init(
        systemImage: String,
        assetImageName: String? = nil,
        title: String,
        description: String,
        ctaTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.assetImageName = assetImageName
        self.title = title
        self.description = description
        self.ctaTitle = ctaTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            illustration

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }

            if let ctaTitle {
                Button(ctaTitle) {
                    action?()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, AppSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .delaydCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var illustration: some View {
        if let assetImageName {
            Image(assetImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 118, height: 118)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
                .shadow(
                    color: AppColors.purplePrimary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                    radius: 16,
                    x: 0,
                    y: 8
                )
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(AppColors.textTertiary(for: colorScheme))
        }
    }
}

extension EmptyStateCard {
    static func mock() -> EmptyStateCard {
        EmptyStateCard(
            systemImage: "target",
            assetImageName: "EmptyGoal",
            title: "No goals yet",
            description: "Create a dream to see how spending changes its timeline.",
            ctaTitle: "Create goal"
        )
    }

    static func mockNoExpenses() -> EmptyStateCard {
        EmptyStateCard(
            systemImage: "clock",
            assetImageName: "ImpactReveal",
            title: "No impacts logged",
            description: "Your delay history will appear here after the first expense."
        )
    }
}

private struct EmptyStateCardPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            EmptyStateCard.mock()
            EmptyStateCard.mockNoExpenses()
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    EmptyStateCardPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    EmptyStateCard(
        systemImage: "sparkles",
        title: "Nothing has delayed this very long goal title yet",
        description: "The first impact will explain how much time moved, without turning this into a transaction list.",
        ctaTitle: "Log first impact"
    )
    .padding(AppSpacing.lg)
    .background(AppColors.backgroundLight)
    .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    EmptyStateCardPreviewGroup()
        .preferredColorScheme(.dark)
}
