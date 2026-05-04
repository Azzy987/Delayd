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
            // without depending on a heavy animation asset.
            if showConfetti {
                ReadyCelebrationOverlay(isVisible: $showConfetti)
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

private struct ReadyCelebrationOverlay: View {
    @Binding var isVisible: Bool
    @State private var animate = false

    private let particles: [(x: CGFloat, y: CGFloat, delay: Double, color: Color)] = [
        (-126, -210, 0.00, AppColors.purplePrimary),
        (-72, -256, 0.04, AppColors.warning),
        (-24, -198, 0.08, AppColors.positive),
        (46, -246, 0.03, AppColors.purplePrimary),
        (112, -204, 0.07, AppColors.warning),
        (-142, -132, 0.10, AppColors.positive),
        (132, -124, 0.12, AppColors.purplePrimary)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(particles.enumerated()), id: \.offset) { index, particle in
                    Capsule()
                        .fill(particle.color.opacity(0.92))
                        .frame(width: index.isMultiple(of: 2) ? 8 : 6, height: index.isMultiple(of: 2) ? 22 : 16)
                        .rotationEffect(.degrees(animate ? Double(index * 38 + 70) : Double(index * 16)))
                        .offset(
                            x: animate ? particle.x : particle.x * 0.28,
                            y: animate ? particle.y : -42
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.1)
                            .delay(particle.delay),
                            value: animate
                        )
                }
            }
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.54)
        }
        .onAppear {
            animate = false
            withAnimation {
                animate = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                isVisible = false
            }
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
