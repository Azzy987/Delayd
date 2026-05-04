import SwiftUI

struct ChooseDreamScreen: View {
    @Binding var selectedDream: GoalCategory?
    let onContinue: () -> Void

    static let stepIndex = 2

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDragProgress) private var dragProgress
    @State private var appearToken = UUID()

    init(selectedDream: Binding<GoalCategory?>, onContinue: @escaping () -> Void = {}) {
        _selectedDream = selectedDream
        self.onContinue = onContinue
    }

    var body: some View {
        ZStack {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.sm) {
                Spacer().frame(height: 42)

                VStack(spacing: AppSpacing.xs) {
                    Text("Choose the dream\nto protect.")
                        .font(.system(.title2, design: .default, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Every expense will be measured against this goal.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .staggeredAppear(delay: 0.08, trigger: appearToken)

                GoalCategoryIllustrationPicker(
                    selectedCategory: $selectedDream,
                    imageSize: 116,
                    style: .raisedCard,
                    columnCount: 3,
                    rowSpacing: AppSpacing.xs,
                    columnSpacing: AppSpacing.xs,
                    categories: chooseDreamCategories
                )
                .staggeredAppear(delay: 0.16, trigger: appearToken)

                Spacer(minLength: AppSpacing.sm)

                VStack(spacing: AppSpacing.md) {
                    pageIndicator(current: 2, total: OnboardingViewModel.totalSteps)
                        .staggeredAppear(delay: 0.24, trigger: appearToken)

                    PrimaryButton("Continue", action: onContinue)
                        .disabled(selectedDream == nil)
                        .opacity(selectedDream == nil ? 0.48 : 1)
                        .staggeredAppear(delay: 0.30, trigger: appearToken)
                }
            }
            .padding(.horizontal, AppSpacing.md)
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

    private var chooseDreamCategories: [GoalCategory] {
        [
            .vacation,
            .tech,
            .gaming,
            .home,
            .vehicle,
            .education,
            .travel,
            .savings,
            .custom
        ]
    }
}

private struct ChooseDreamPreviewHost: View {
    @State private var selectedDream: GoalCategory?

    var body: some View {
        ChooseDreamScreen(selectedDream: $selectedDream)
    }
}

#Preview("Light") {
    ChooseDreamPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ChooseDreamPreviewHost()
        .preferredColorScheme(.dark)
}
