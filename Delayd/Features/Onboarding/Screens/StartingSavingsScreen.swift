import SwiftUI

struct StartingSavingsScreen: View {
    @Binding var startingSavedAmount: String
    @Binding var savingsLocation: DreamSavingsLocation
    @Binding var goalName: String
    @Binding var goalAmount: String
    @Binding var monthlyTarget: String
    @Binding var goalDate: Date?
    let currencyCode: String
    let onContinue: () -> Void

    static let stepIndex = 5

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDragProgress) private var dragProgress
    @State private var appearToken = UUID()
    @FocusState private var isFocused: Bool

    init(
        startingSavedAmount: Binding<String>,
        savingsLocation: Binding<DreamSavingsLocation>,
        goalName: Binding<String>,
        goalAmount: Binding<String> = .constant(""),
        monthlyTarget: Binding<String> = .constant(""),
        goalDate: Binding<Date?> = .constant(nil),
        currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode,
        onContinue: @escaping () -> Void = {}
    ) {
        _startingSavedAmount = startingSavedAmount
        _savingsLocation = savingsLocation
        _goalName = goalName
        _goalAmount = goalAmount
        _monthlyTarget = monthlyTarget
        _goalDate = goalDate
        self.currencyCode = currencyCode
        self.onContinue = onContinue
    }

    var body: some View {
        ZStack {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.sm) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.md) {
                        Spacer().frame(height: 24)

                        OnboardingIllustration("OnboardingSavingsLocation", size: 150)
                            .staggeredAppear(delay: 0.04, trigger: appearToken)

                        VStack(spacing: AppSpacing.xs) {
                            Text("What have you\nalready protected?")
                                .font(.system(.title2, design: .default, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Add the money already kept aside for \(dreamName).")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .staggeredAppear(delay: 0.08, trigger: appearToken)

                        amountCard
                            .staggeredAppear(delay: 0.14, trigger: appearToken)

                        locationCard
                            .staggeredAppear(delay: 0.20, trigger: appearToken)

                        helperPill
                            .staggeredAppear(delay: 0.28, trigger: appearToken)

                        if let feasibility = feasibilityResult {
                            feasibilityPill(feasibility)
                                .staggeredAppear(delay: 0.32, trigger: appearToken)
                        }
                    }
                }

                VStack(spacing: AppSpacing.md) {
                    pageIndicator(current: Self.stepIndex, total: OnboardingViewModel.totalSteps)
                        .staggeredAppear(delay: 0.34, trigger: appearToken)

                    PrimaryButton("Continue") {
                        isFocused = false
                        onContinue()
                    }
                    .staggeredAppear(delay: 0.40, trigger: appearToken)
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

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Already protected")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(CurrencyFormatter.symbol(for: currencyCode))
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                TextField("0", text: $startingSavedAmount)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .keyboardType(.numberPad)
                    .minimumScaleFactor(0.55)
                    .focused($isFocused)
            }
        }
        .delaydCard()
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Where is it kept?")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                ForEach(DreamSavingsLocation.allCases) { location in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            savingsLocation = location
                        }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: location.symbolName)
                                .font(.system(size: 14, weight: .bold))
                            Text(location.title)
                                .font(AppTypography.captionMedium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .foregroundStyle(location == savingsLocation ? .white : AppColors.textPrimary(for: colorScheme))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .padding(.horizontal, AppSpacing.sm)
                        .background(
                            location == savingsLocation
                                ? AnyShapeStyle(AppGradients.heroGradient)
                                : AnyShapeStyle(AppColors.softSurface(for: colorScheme)),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .delaydCard()
    }

    private var helperPill: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.positive)

            Text("This is not income tracking. It is the starting amount already protected for your dream.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.softPositiveBackground.opacity(colorScheme == .dark ? 0.18 : 1), in: RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    private var dreamName: String {
        let trimmed = goalName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "your dream" : trimmed.delaydGoalTitleCased
    }

    private var feasibilityResult: GoalFeasibility.Result? {
        GoalFeasibility.evaluate(
            targetAmount: decimalValue(from: goalAmount),
            protectedAmount: decimalValue(from: startingSavedAmount),
            monthlyTarget: decimalValue(from: monthlyTarget),
            deadline: goalDate,
            currencyCode: currencyCode
        )
    }

    private func feasibilityPill(_ result: GoalFeasibility.Result) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: result.isPossible ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(result.isPossible ? AppColors.positive : AppColors.warning)

            Text(result.message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            (result.isPossible ? AppColors.softPositiveBackground : AppColors.softWarningBackground)
                .opacity(colorScheme == .dark ? 0.18 : 1),
            in: RoundedRectangle(cornerRadius: AppRadius.lg)
        )
    }

    private func decimalValue(from text: String) -> Double {
        Double(text.filter { $0.isNumber || $0 == "." }) ?? 0
    }
}

private struct StartingSavingsPreviewHost: View {
    @State private var amount = "5000"
    @State private var location = DreamSavingsLocation.piggyBank
    @State private var goalName = "Bali trip"
    @State private var goalAmount = "120000"
    @State private var monthlyTarget = "10000"
    @State private var goalDate: Date? = Calendar.current.date(byAdding: .month, value: 12, to: .now)

    var body: some View {
        StartingSavingsScreen(
            startingSavedAmount: $amount,
            savingsLocation: $location,
            goalName: $goalName,
            goalAmount: $goalAmount,
            monthlyTarget: $monthlyTarget,
            goalDate: $goalDate
        )
    }
}

#Preview("Light") {
    StartingSavingsPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    StartingSavingsPreviewHost()
        .preferredColorScheme(.dark)
}
