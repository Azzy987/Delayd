import SwiftUI

/// Full-screen onboarding layout with one continuous purple background and a
/// floating white card anchored above the home indicator.
struct OnboardingPageLayout<Content: View>: View {
    let lottieName: String?
    let lottieSize: CGFloat
    let illustrationName: String?
    let illustrationSize: CGFloat
    let keepsCardAboveSafeArea: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDragProgress) private var dragProgress

    /// Lottie animation variant
    init(
        lottie: String?,
        lottieSize: CGFloat = 220,
        keepsCardAboveSafeArea: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.lottieName = lottie
        self.lottieSize = lottieSize
        self.illustrationName = nil
        self.illustrationSize = 0
        self.keepsCardAboveSafeArea = keepsCardAboveSafeArea
        self.content = content
    }

    /// Static illustration variant (for ReadyScreen etc.)
    init(
        illustration: String,
        illustrationSize: CGFloat = 160,
        keepsCardAboveSafeArea: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.lottieName = nil
        self.lottieSize = 0
        self.illustrationName = illustration
        self.illustrationSize = illustrationSize
        self.keepsCardAboveSafeArea = keepsCardAboveSafeArea
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let dragAmount = min(abs(CGFloat(dragProgress.dragFraction)), 1)
            let bottomGap = keepsCardAboveSafeArea
                ? max(AppSpacing.md, proxy.safeAreaInsets.bottom + AppSpacing.sm)
                : AppSpacing.xs

            ZStack {
                fullScreenBackground

                VStack(spacing: 0) {
                    heroArt
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    bottomCard
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, bottomGap)
                        .scaleEffect(1 - dragAmount * 0.018)
                        .animation(.spring(response: 0.44, dampingFraction: 0.72), value: dragProgress.dragFraction)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    // MARK: - Sub-views

    private var fullScreenBackground: some View {
        ZStack {
            AppGradients.heroGradient
            decorativePattern
        }
        .ignoresSafeArea()
    }

    private var heroArt: some View {
        // Parallax: foreground art shifts opposite to the drag for depth.
        // Clamp to ±28pt so the effect stays subtle even on big swipes.
        let artOffset = max(-28, min(28, CGFloat(dragProgress.dragFraction) * -36))

        return ZStack {
            if let name = lottieName {
                LottieAnimationView(name, size: lottieSize)
                    .offset(x: artOffset)
            }

            if let name = illustrationName {
                OnboardingIllustration(name, size: illustrationSize)
                    .offset(x: artOffset)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomCard: some View {
        VStack(spacing: AppSpacing.md) {
            content()
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.xl)
        .padding(.bottom, AppSpacing.lg)
        .background(
            AppColors.surface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: AppRadius.xl + 12, style: .continuous)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.10), radius: 22, x: 0, y: 10)
    }

    private var decorativePattern: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 180, height: 180)
                .offset(x: -150, y: -250)

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 110, height: 110)
                .offset(x: 150, y: -120)

            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 74, height: 74)
                .offset(x: -125, y: 120)

            Circle()
                .fill(.white.opacity(0.045))
                .frame(width: 240, height: 240)
                .offset(x: 140, y: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Lottie Layout") {
    OnboardingPageLayout(lottie: "LottieWelcome") {
        VStack(spacing: AppSpacing.sm) {
            Text("Dreams move in days.")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimaryLight)
                .multilineTextAlignment(.center)

            Text("Delayd shows you the time-cost of every expense.")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondaryLight)
                .multilineTextAlignment(.center)
        }

        PrimaryButton("Get Started")
    }
    .preferredColorScheme(.light)
}

#Preview("Illustration Layout") {
    OnboardingPageLayout(illustration: "OnboardingReady") {
        Text("Your dream is now protected.")
            .font(AppTypography.sectionHeader)
            .foregroundStyle(AppColors.textPrimaryDark)
            .multilineTextAlignment(.center)

        PrimaryButton("Enter Delayd")
    }
    .preferredColorScheme(.dark)
}
