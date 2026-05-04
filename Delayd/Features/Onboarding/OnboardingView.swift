import SwiftUI
import SwiftData

struct OnboardingView: View {
    @State private var viewModel: OnboardingViewModel
    let showsDebugControls: Bool
    let onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    init(
        viewModel: OnboardingViewModel = OnboardingViewModel(),
        showsDebugControls: Bool = false,
        onComplete: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel)
        self.showsDebugControls = showsDebugControls
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            onboardingBackground

            KavsoftCarousel(
                currentIndex: $viewModel.currentStep,
                data: Array(0..<OnboardingViewModel.totalSteps)
            ) { step, _ in
                screen(for: step)
            }

            // ── Top nav bar overlay ──
            VStack {
                HStack {
                    // Back button
                    if viewModel.currentStep > 0 {
                        Button {
                            viewModel.back()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(backButtonForeground)
                                .frame(width: 40, height: 40)
                                .background(backButtonBackground, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }

                    Spacer()

                    // Skip button
                    if isSkippableStep {
                        Button {
                            if viewModel.currentStep == 7 {
                                completeOnboarding()
                            } else {
                                viewModel.next()
                            }
                        } label: {
                            Text("Skip")
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(skipButtonColor)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(skipButtonBg, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, 8)

                Spacer()

                if showsDebugControls {
                    debugControls
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.lg)
                }
            }
        }
        // Dismiss keyboard when switching screens
        .onChange(of: viewModel.currentStep) { _, _ in
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.purplePrimary)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func screen(for step: Int) -> some View {
        switch step {
        case 0:
            WelcomeScreen { viewModel.next() }
        case 1:
            InsightScreen { viewModel.next() }
        case 2:
            ChooseDreamScreen(selectedDream: $viewModel.selectedDream) {
                prefillGoalNameIfNeeded()
                viewModel.next()
            }
        case 3:
            GoalDetailsScreen(
                goalName: $viewModel.goalName,
                goalAmount: $viewModel.goalAmount,
                goalDate: $viewModel.goalDate,
                selectedDream: viewModel.selectedDream,
                currencyCode: viewModel.currencyCode
            ) {
                viewModel.next()
            }
        case 4:
            SavingsTargetScreen(
                monthlyTarget: $viewModel.monthlyTarget,
                goalAmount: $viewModel.goalAmount,
                goalDate: $viewModel.goalDate,
                currencyCode: viewModel.currencyCode
            ) {
                viewModel.next()
            }
        case 5:
            StartingSavingsScreen(
                startingSavedAmount: $viewModel.startingSavedAmount,
                savingsLocation: $viewModel.savingsLocation,
                goalName: $viewModel.goalName,
                goalAmount: $viewModel.goalAmount,
                monthlyTarget: $viewModel.monthlyTarget,
                goalDate: $viewModel.goalDate,
                currencyCode: viewModel.currencyCode
            ) {
                viewModel.next()
            }
        case 6:
            ToneScreen(selectedTone: $viewModel.selectedTone) {
                viewModel.next()
            }
        case 7:
            PermissionsScreen(
                notificationsEnabled: $viewModel.notificationsEnabled,
                hapticsEnabled: $viewModel.hapticsEnabled,
                showsSkipButton: false,
                onSkip: { completeOnboarding() },
                onContinue: { viewModel.next() }
            )
        default:
            ReadyScreen { completeOnboarding() }
        }
    }

    /// Screens that use the gradient-top layout (illustration screens)
    private var isGradientStep: Bool {
        [0, 1, 7, 8].contains(viewModel.currentStep)
    }

    @ViewBuilder
    private var onboardingBackground: some View {
        if isGradientStep {
            AppGradients.heroGradient
                .ignoresSafeArea()
        } else {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()
        }
    }

    /// Screens that can be skipped
    private var isSkippableStep: Bool {
        [3, 4, 5, 6, 7].contains(viewModel.currentStep)
    }

    // Back button styling — theme-aware
    private var backButtonForeground: Color {
        isGradientStep ? .white : AppColors.textPrimary(for: colorScheme)
    }

    private var backButtonBackground: some ShapeStyle {
        isGradientStep
            ? AnyShapeStyle(.white.opacity(0.15))
            : AnyShapeStyle(AppColors.surface(for: colorScheme))
    }

    // Skip button styling — theme-aware
    private var skipButtonColor: Color {
        isGradientStep ? .white : AppColors.textSecondary(for: colorScheme)
    }

    private var skipButtonBg: some ShapeStyle {
        isGradientStep
            ? AnyShapeStyle(.white.opacity(0.15))
            : AnyShapeStyle(AppColors.surface(for: colorScheme))
    }

    private var debugControls: some View {
        HStack(spacing: AppSpacing.md) {
            SecondaryButton("Back") {
                viewModel.back()
            }
            .disabled(viewModel.currentStep == 0)

            PrimaryButton(viewModel.currentStep == OnboardingViewModel.totalSteps - 1 ? "Complete" : "Next") {
                viewModel.next()
            }
        }
    }

    private func prefillGoalNameIfNeeded() {
        let trimmedName = viewModel.goalName.trimmingCharacters(in: .whitespacesAndNewlines)

        if viewModel.selectedDream == .custom {
            if trimmedName.isEmpty || defaultGoalNames.contains(trimmedName) {
                viewModel.goalName = ""
            }
            return
        }

        guard trimmedName.isEmpty else { return }
        viewModel.goalName = defaultGoalName(for: viewModel.selectedDream)
    }

    private func defaultGoalName(for category: GoalCategory?) -> String {
        switch category {
        case .travel: "Bali trip"
        case .vacation: "Beach vacation"
        case .tech: "New iPhone"
        case .gaming: "Gaming setup"
        case .home: "Home upgrade"
        case .vehicle: "New car"
        case .education: "Course fund"
        case .wedding: "Wedding fund"
        case .emergency: "Emergency fund"
        case .savings: "Freedom fund"
        case .custom, nil: "My dream"
        }
    }

    private var defaultGoalNames: Set<String> {
        Set(GoalCategory.pickerPresets.map { defaultGoalName(for: $0) })
    }

    private func completeOnboarding() {
        Task {
            await viewModel.complete(modelContainer: modelContext.container)
            onComplete()
        }
    }
}

#Preview("Light") {
    OnboardingView(showsDebugControls: true)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    OnboardingView(showsDebugControls: true)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
