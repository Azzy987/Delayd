import SwiftUI

struct ReadyScreen: View {
    let onEnter: () -> Void

    static let stepIndex = 8

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDragProgress) private var dragProgress
    @State private var isPulsing = false
    @State private var showConfetti = false
    @State private var appearToken = UUID()

    init(onEnter: @escaping () -> Void = {}) {
        self.onEnter = onEnter
    }

    var body: some View {
        ZStack {
            OnboardingPageLayout(illustration: "OnboardingReady", illustrationSize: 330) {
                VStack(spacing: AppSpacing.sm) {
                    Text("Your dream is\nnow protected.")
                        .font(.system(.title, design: .default, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Log your first expense to see\nhow it works.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .staggeredAppear(delay: 0.05, trigger: appearToken)

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(AppColors.positive)

                    Text("Protected")
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.positive)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .background(
                    AppColors.softPositiveBackground.opacity(colorScheme == .dark ? 0.18 : 1),
                    in: Capsule()
                )
                .scaleEffect(isPulsing ? 1.04 : 1)
                .animation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .staggeredAppear(delay: 0.18, trigger: appearToken)

                pageIndicator(current: Self.stepIndex, total: OnboardingViewModel.totalSteps)
                    .padding(.top, AppSpacing.sm)
                    .staggeredAppear(delay: 0.26, trigger: appearToken)

                PrimaryButton("Enter Delayd", action: onEnter)
                    .staggeredAppear(delay: 0.32, trigger: appearToken)
            }

            // Full-screen native accent overlay; keeps the final screen light
            // using the bundled Lottie confetti animation.
            if showConfetti {
                LottieOverlay(animationName: "Confetti", isPlaying: $showConfetti)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            isPulsing = true
            if dragProgress.activeIndex == Self.stepIndex {
                appearToken = UUID()
                triggerConfetti()
            }
        }
        .onChange(of: dragProgress.activeIndex) { _, newValue in
            if newValue == Self.stepIndex {
                appearToken = UUID()
                triggerConfetti()
            }
        }
    }

    private func triggerConfetti() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showConfetti = true
        }
    }
}

#Preview("Light") {
    ReadyScreen()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ReadyScreen()
        .preferredColorScheme(.dark)
}
