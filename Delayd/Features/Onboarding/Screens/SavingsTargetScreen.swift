import SwiftUI

struct SavingsTargetScreen: View {
    @Binding var monthlyTarget: String
    @Binding var goalAmount: String
    @Binding var goalDate: Date?
    let currencyCode: String
    let onContinue: () -> Void

    static let stepIndex = 4

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDragProgress) private var dragProgress
    @State private var appearToken = UUID()
    @State private var isCustomMode = false
    @FocusState private var isFocused: Bool

    init(
        monthlyTarget: Binding<String>,
        goalAmount: Binding<String>,
        goalDate: Binding<Date?> = .constant(nil),
        currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode,
        onContinue: @escaping () -> Void = {}
    ) {
        _monthlyTarget = monthlyTarget
        _goalAmount = goalAmount
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
                    VStack(spacing: AppSpacing.sm) {
                        Spacer().frame(height: 30)

                        OnboardingIllustration(GoalCategory.savings.illustrationAssetName, size: 136)
                            .staggeredAppear(delay: 0.04, trigger: appearToken)

                        VStack(spacing: AppSpacing.xs) {
                            Text("What can you\nsave monthly?")
                                .font(.system(.title2, design: .default, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("This becomes the baseline for every delay.")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .staggeredAppear(delay: 0.08, trigger: appearToken)

                        amountDisplay
                            .staggeredAppear(delay: 0.14, trigger: appearToken)

                        if isCustomMode {
                            customEntryCard
                                .staggeredAppear(delay: 0.20, trigger: appearToken)
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                        } else {
                            presetGrid
                                .staggeredAppear(delay: 0.20, trigger: appearToken)
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                        }

                        helperPill
                            .staggeredAppear(delay: 0.28, trigger: appearToken)

                        if let feasibility = feasibilityResult {
                            feasibilityPill(feasibility)
                                .staggeredAppear(delay: 0.32, trigger: appearToken)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                VStack(spacing: AppSpacing.md) {
                    pageIndicator(current: 4, total: OnboardingViewModel.totalSteps)
                        .staggeredAppear(delay: 0.34, trigger: appearToken)

                    PrimaryButton("Continue", action: {
                        isFocused = false
                        onContinue()
                    })
                        .disabled(monthlyTarget.isEmpty)
                        .opacity(monthlyTarget.isEmpty ? 0.48 : 1)
                        .staggeredAppear(delay: 0.40, trigger: appearToken)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if dragProgress.activeIndex == Self.stepIndex, isFocused {
                    Spacer()
                    Button("Done") {
                        isFocused = false
                    }
                    .font(.system(size: 15, weight: .semibold))
                }
            }
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

    // MARK: - Amount display

    private var amountDisplay: some View {
        let displayValue = decimalValue(from: monthlyTarget)
        return HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
            Text(CurrencyFormatter.symbol(for: currencyCode))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            Text(displayValue > 0 ? formatted(displayValue) : "0")
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            Text("/mo")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Preset grid

    private var presetGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: AppSpacing.sm),
            GridItem(.flexible(), spacing: AppSpacing.sm)
        ]

        return LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
            ForEach(presetAmounts, id: \.self) { amount in
                presetChip(amount: amount)
            }
            customChip
        }
    }

    private func presetChip(amount: Double) -> some View {
        let isSelected = !isCustomMode && abs(decimalValue(from: monthlyTarget) - amount) < 0.5

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                monthlyTarget = String(Int(amount))
                isCustomMode = false
            }
        } label: {
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected
                                ? AnyShapeStyle(AppGradients.heroGradient)
                                : AnyShapeStyle(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.28 : 1))
                        )
                        .frame(width: 34, height: 34)

                    Image(systemName: isSelected ? "checkmark" : currencySymbolIcon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isSelected ? .white : AppColors.purplePrimary)
                }

                Text(CurrencyFormatter.format(amount, currencyCode: currencyCode))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        isSelected
                            ? AppColors.purplePrimary
                            : AppColors.textPrimary(for: colorScheme)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(presetSubtitle(for: amount))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .background(
                isSelected
                    ? AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.28 : 1)
                    : AppColors.surface(for: colorScheme),
                in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(
                        isSelected
                            ? AppColors.purplePrimary
                            : AppColors.border(for: colorScheme),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .animation(.easeInOut(duration: 0.18), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var customChip: some View {
        Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                isCustomMode = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFocused = true
            }
        } label: {
            VStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.28 : 1))
                        .frame(width: 34, height: 34)
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.purplePrimary)
                }

                Text("Custom amount")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.purplePrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .background(
                AppColors.surface(for: colorScheme),
                in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(AppColors.purplePrimary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom entry

    private var customEntryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Enter custom amount")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.76)) {
                        isCustomMode = false
                        isFocused = false
                    }
                } label: {
                    Text("Use presets")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.purplePrimary)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(CurrencyFormatter.symbol(for: currencyCode))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                TextField("10000", text: $monthlyTarget)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .keyboardType(.numberPad)
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)
                    .focused($isFocused)
                    .onChange(of: monthlyTarget) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            monthlyTarget = filtered
                        }
                    }
            }

        }
        .delaydCard()
    }

    // MARK: - Helper pill

    private var helperPill: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.purplePrimary)

            Text(helperText)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.18 : 1),
            in: RoundedRectangle(cornerRadius: AppRadius.lg)
        )
    }

    // MARK: - Logic

    /// Three preset amounts derived from the goal: roughly 6%, 10%, 16% of
    /// the goal amount, rounded to nice round numbers. Falls back to fixed
    /// defaults when the goal amount is missing.
    private var presetAmounts: [Double] {
        let goal = decimalValue(from: goalAmount)
        guard goal > 0 else { return [5_000, 10_000, 20_000] }

        let raw = [goal * 0.06, goal * 0.10, goal * 0.16]
        return raw.map(roundToNice).removingDuplicates()
    }

    private func roundToNice(_ value: Double) -> Double {
        let magnitude: Double
        switch value {
        case ..<1_000: magnitude = 100
        case ..<10_000: magnitude = 500
        case ..<100_000: magnitude = 1_000
        default: magnitude = 5_000
        }
        return max(magnitude, (value / magnitude).rounded() * magnitude)
    }

    private func presetSubtitle(for amount: Double) -> String {
        let goal = decimalValue(from: goalAmount)
        guard goal > 0 else { return "/month" }
        let months = max(1, Int(ceil(goal / amount)))
        return "~\(months) mo to goal"
    }

    private var helperText: String {
        let amount = decimalValue(from: goalAmount)
        let target = decimalValue(from: monthlyTarget)

        guard amount > 0, target > 0 else {
            return "Your monthly target becomes the baseline for every delay."
        }

        let months = max(1, Int(ceil(amount / target)))
        return "At \(CurrencyFormatter.format(target, currencyCode: currencyCode))/month, you'll reach your goal in ~\(months) months."
    }

    private var feasibilityResult: GoalFeasibility.Result? {
        GoalFeasibility.evaluate(
            targetAmount: decimalValue(from: goalAmount),
            protectedAmount: 0,
            monthlyTarget: decimalValue(from: monthlyTarget),
            deadline: goalDate,
            currencyCode: currencyCode
        )
    }

    private var currencySymbolIcon: String {
        switch currencyCode.uppercased() {
        case "INR": "indianrupeesign"
        case "GBP": "sterlingsign"
        case "EUR": "eurosign"
        case "JPY", "CNY": "yensign"
        default: "dollarsign"
        }
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
        let filtered = text.filter { $0.isNumber || $0 == "." }
        return Double(filtered) ?? 0
    }

    private func formatted(_ value: Double) -> String {
        Self.decimalFormatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private struct SavingsTargetPreviewHost: View {
    @State private var monthlyTarget = "10000"
    @State private var goalAmount = "120000"
    @State private var goalDate: Date? = Calendar.current.date(byAdding: .month, value: 12, to: .now)

    var body: some View {
        SavingsTargetScreen(monthlyTarget: $monthlyTarget, goalAmount: $goalAmount, goalDate: $goalDate)
    }
}

#Preview("Light") {
    SavingsTargetPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SavingsTargetPreviewHost()
        .preferredColorScheme(.dark)
}
