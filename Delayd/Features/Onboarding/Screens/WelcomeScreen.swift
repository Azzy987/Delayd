import SwiftUI

struct WelcomeScreen: View {
    static let stepIndex = 0
    let onGetStarted: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDragProgress) private var dragProgress
    @State private var appearToken = UUID()

    init(onGetStarted: @escaping () -> Void = {}) {
        self.onGetStarted = onGetStarted
    }

    var body: some View {
        OnboardingPageLayout(lottie: "LottieWelcome", lottieSize: 360, keepsCardAboveSafeArea: true) {
            VStack(spacing: AppSpacing.sm) {
                Text("Dreams move\nin days.")
                    .font(.system(.largeTitle, design: .default, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Delayd shows how every expense\ndelays what matters most to you.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .staggeredAppear(delay: 0.05, trigger: appearToken)

            pageIndicator(current: 0, total: OnboardingViewModel.totalSteps)
                .padding(.top, AppSpacing.sm)
                .staggeredAppear(delay: 0.18, trigger: appearToken)

            PrimaryButton("Get Started", action: onGetStarted)
                .staggeredAppear(delay: 0.26, trigger: appearToken)
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

// MARK: - Shared page indicator

func pageIndicator(current: Int, total: Int) -> some View {
    HStack(spacing: AppSpacing.xs) {
        ForEach(0..<total, id: \.self) { index in
            Capsule()
                .fill(index == current ? AppColors.purplePrimary : AppColors.softPurpleBackground)
                .frame(width: index == current ? 22 : 8, height: 8)
                .animation(AppMotion.forwardProgress, value: current)
        }
    }
}

#Preview("Light") {
    WelcomeScreen()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    WelcomeScreen()
        .preferredColorScheme(.dark)
}
