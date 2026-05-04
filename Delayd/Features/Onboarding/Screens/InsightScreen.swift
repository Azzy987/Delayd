import SwiftUI

struct InsightScreen: View {
    static let stepIndex = 1
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDragProgress) private var dragProgress
    @State private var appearToken = UUID()

    init(onContinue: @escaping () -> Void = {}) {
        self.onContinue = onContinue
    }

    var body: some View {
        OnboardingPageLayout(lottie: "LottieInsight", lottieSize: 280) {
            VStack(spacing: AppSpacing.sm) {
                Text("Every expense has\na hidden cost.")
                    .font(.system(.title2, design: .default, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("A purchase isn't just money leaving.\nIt's time moving away from your dream.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .staggeredAppear(delay: 0.05, trigger: appearToken)

            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(CurrencyFormatter.format(2_000, currencyCode: CurrencyFormatter.localeDefaultCurrencyCode)) on dinner")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    Text("Delayed Bali trip by 6 days")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.negative)
                }
                Spacer()
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 24))
                    .foregroundStyle(AppColors.negative)
            }
            .padding(AppSpacing.md)
            .background(
                AppColors.softNegativeBackground.opacity(colorScheme == .dark ? 0.18 : 1),
                in: RoundedRectangle(cornerRadius: AppRadius.lg)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.negative.opacity(0.2), lineWidth: 1)
            }
            .staggeredAppear(delay: 0.16, trigger: appearToken)

            // Cultural anchor — a generic observation about people, not a
            // claim about Delayd users. Sets expectation without inventing
            // social proof we don't yet have.
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "hourglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                Text("Most people delay their dream by 2 years without realizing it.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.xs)
            .staggeredAppear(delay: 0.22, trigger: appearToken)

            pageIndicator(current: 1, total: OnboardingViewModel.totalSteps)
                .padding(.top, AppSpacing.sm)
                .staggeredAppear(delay: 0.28, trigger: appearToken)

            PrimaryButton("Show me how", action: onContinue)
                .staggeredAppear(delay: 0.34, trigger: appearToken)
        }
        .onAppear {
            if dragProgress.activeIndex == Self.stepIndex {
                appearToken = UUID()
            }
        }
        .onChange(of: dragProgress.activeIndex) { _, newValue in
            if newValue == Self.stepIndex {
                appearToken = UUID()
            }
        }
    }
}

#Preview("Light") {
    InsightScreen()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    InsightScreen()
        .preferredColorScheme(.dark)
}
