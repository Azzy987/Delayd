import SwiftUI

/// Onboarding step that lets the user pick an emotional tone for in-app copy.
/// Each option shows its own `sampleLine` so the user actually feels the voice
/// before committing — this directly reduces post-install surprise when
/// nudges, insights, and reveals start speaking back in that tone.
struct ToneScreen: View {
    @Binding var selectedTone: DelaydTone
    let onContinue: () -> Void

    static let stepIndex = 6

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDragProgress) private var dragProgress
    @State private var appearToken = UUID()

    init(selectedTone: Binding<DelaydTone>, onContinue: @escaping () -> Void = {}) {
        _selectedTone = selectedTone
        self.onContinue = onContinue
    }

    var body: some View {
        ZStack {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.sm) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.sm) {
                        Spacer().frame(height: 20)

                        OnboardingIllustration("OnboardingTone", size: 177)
                            .staggeredAppear(delay: 0.04, trigger: appearToken)

                        VStack(spacing: AppSpacing.xs) {
                            Text("How should we talk to you?")
                                .font(.system(.title3, design: .default, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                .multilineTextAlignment(.center)

                            Text("This voice appears in nudges, insights, and reveals.")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .staggeredAppear(delay: 0.08, trigger: appearToken)

                        VStack(spacing: AppSpacing.sm) {
                            ForEach(DelaydTone.allCases) { tone in
                                ToneOptionCard(
                                    tone: tone,
                                    isSelected: tone == selectedTone,
                                    onTap: { selectedTone = tone }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, AppSpacing.xs)
                        .staggeredAppear(delay: 0.16, trigger: appearToken)
                    }
                }

                VStack(spacing: AppSpacing.md) {
                    pageIndicator(current: Self.stepIndex, total: OnboardingViewModel.totalSteps)
                        .staggeredAppear(delay: 0.26, trigger: appearToken)

                    PrimaryButton("Continue", action: onContinue)
                        .staggeredAppear(delay: 0.32, trigger: appearToken)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
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

private struct ToneOptionCard: View {
    let tone: DelaydTone
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.md) {
                    // Larger emoji tile with gradient fill when selected.
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .fill(
                                isSelected
                                    ? AnyShapeStyle(AppGradients.heroGradient)
                                    : AnyShapeStyle(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.28 : 1))
                            )
                            .frame(width: 56, height: 56)

                        Text(tone.emoji)
                            .font(.system(size: 28))
                    }
                    .scaleEffect(isSelected ? 1.04 : 1)
                    .animation(.spring(response: 0.32, dampingFraction: 0.74), value: isSelected)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tone.title)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        Text(tone.subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    }

                    Spacer(minLength: AppSpacing.xs)

                    // Filled checkmark when selected, hollow ring otherwise —
                    // clearer affordance than a thick-stroke circle.
                    ZStack {
                        Circle()
                            .stroke(
                                isSelected ? AppColors.purplePrimary : AppColors.border(for: colorScheme),
                                lineWidth: 1.5
                            )
                            .frame(width: 24, height: 24)

                        if isSelected {
                            Circle()
                                .fill(AppColors.purplePrimary)
                                .frame(width: 24, height: 24)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isSelected)
                }

                // Sample line — users see how each tone actually speaks.
                Text("“\(tone.sampleLine)”")
                    .font(AppTypography.callout)
                    .italic()
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                if let warning = tone.intensityWarning {
                    HStack(alignment: .top, spacing: AppSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.warning)
                        Text(warning)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.warning)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected
                    ? AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.18 : 0.6)
                    : AppColors.surface(for: colorScheme),
                in: RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                    .stroke(
                        isSelected ? AppColors.purplePrimary.opacity(0.4) : AppColors.border(for: colorScheme),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.18 : (isSelected ? 0.08 : 0.04)),
                radius: isSelected ? 8 : 4,
                x: 0,
                y: 2
            )
            .scaleEffect(isSelected ? 1.005 : 1)
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct ToneScreenPreviewHost: View {
    @State private var tone: DelaydTone = .motivational

    var body: some View {
        ToneScreen(selectedTone: $tone)
    }
}

#Preview("Light") {
    ToneScreenPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ToneScreenPreviewHost()
        .preferredColorScheme(.dark)
}
