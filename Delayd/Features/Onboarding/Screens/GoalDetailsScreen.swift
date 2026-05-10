import SwiftUI

struct GoalDetailsScreen: View {
    @Binding var goalName: String
    @Binding var goalAmount: String
    @Binding var goalDate: Date?
    let selectedDream: GoalCategory?
    let currencyCode: String
    let onContinue: () -> Void

    static let stepIndex = 3

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.onboardingDragProgress) private var dragProgress
    @State private var targetDate: Date
    @State private var figureOutLater: Bool
    @State private var appearToken = UUID()
    @State private var isDatePickerPresented = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, amount
    }

    init(
        goalName: Binding<String>,
        goalAmount: Binding<String>,
        goalDate: Binding<Date?>,
        selectedDream: GoalCategory?,
        currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode,
        onContinue: @escaping () -> Void = {}
    ) {
        _goalName = goalName
        _goalAmount = goalAmount
        _goalDate = goalDate
        self.selectedDream = selectedDream
        self.currencyCode = currencyCode
        self.onContinue = onContinue

        let fallbackDate = Calendar.current.date(byAdding: .month, value: 12, to: .now) ?? .now
        _targetDate = State(initialValue: goalDate.wrappedValue ?? fallbackDate)
        _figureOutLater = State(initialValue: goalDate.wrappedValue == nil)
    }

    var body: some View {
        ZStack {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.sm) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.sm) {
                        Spacer().frame(height: 30)

                        OnboardingIllustration(selectedDream?.illustrationAssetName ?? GoalCategory.custom.illustrationAssetName, size: 136)
                            .staggeredAppear(delay: 0.04, trigger: appearToken)

                        VStack(spacing: AppSpacing.xs) {
                            Text(titleText)
                                .font(.system(.title3, design: .default, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Clear goals make each delay feel sharper.")
                                .font(AppTypography.callout)
                                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .staggeredAppear(delay: 0.10, trigger: appearToken)

                        VStack(spacing: AppSpacing.sm) {
                            inputCard(title: nameFieldTitle) {
                                TextField(namePlaceholder, text: $goalName)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                    .textInputAutocapitalization(.words)
                                    .submitLabel(.next)
                                    .focused($focusedField, equals: .name)
                                    .onSubmit { focusedField = .amount }
                            }

                            inputCard(title: "Target amount") {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                                        Text(CurrencyFormatter.symbol(for: currencyCode))
                                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                                        TextField("120000", text: $goalAmount)
                                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                            .keyboardType(.numberPad)
                                            .minimumScaleFactor(0.72)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .focused($focusedField, equals: .amount)
                                            .onChange(of: goalAmount) { _, newValue in
                                                let filtered = newValue.filter { $0.isNumber }
                                                if filtered != newValue {
                                                    goalAmount = filtered
                                                }
                                            }
                                    }

                                }
                            }

                            inputCard(title: "Target date") {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    Button {
                                        focusedField = nil
                                        isDatePickerPresented = true
                                    } label: {
                                        HStack(spacing: AppSpacing.sm) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundStyle(AppColors.purplePrimary)

                                            Text(targetDate.formatted(.dateTime.day().month(.wide).year()))
                                                .font(AppTypography.bodyMedium)
                                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(AppColors.textTertiary(for: colorScheme))
                                        }
                                        .padding(AppSpacing.md)
                                        .background(AppColors.background(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.md))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(figureOutLater)
                                    .opacity(figureOutLater ? 0.45 : 1)

                                    Toggle("I'll figure it out later", isOn: $figureOutLater)
                                        .font(AppTypography.callout)
                                        .tint(AppColors.purplePrimary)
                                }
                            }
                        }
                        .staggeredAppear(delay: 0.18, trigger: appearToken)
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                VStack(spacing: AppSpacing.md) {
                    pageIndicator(current: 3, total: OnboardingViewModel.totalSteps)
                        .staggeredAppear(delay: 0.28, trigger: appearToken)

                    PrimaryButton("Continue", action: {
                        focusedField = nil
                        onContinue()
                    })
                        .disabled(goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || goalAmount.isEmpty)
                        .opacity(goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || goalAmount.isEmpty ? 0.48 : 1)
                        .staggeredAppear(delay: 0.34, trigger: appearToken)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .sheet(isPresented: $isDatePickerPresented) {
            datePickerSheet
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if dragProgress.activeIndex == Self.stepIndex, focusedField != nil {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
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
        .onChange(of: targetDate) { _, newValue in
            if !figureOutLater {
                goalDate = newValue
            }
        }
        .onChange(of: figureOutLater) { _, newValue in
            goalDate = newValue ? nil : targetDate
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                DatePicker("Dream date", selection: $targetDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(AppColors.purplePrimary)
                    .padding(.horizontal, AppSpacing.md)

                PrimaryButton("Done") {
                    isDatePickerPresented = false
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            }
            .padding(.top, AppSpacing.sm)
            .background(AppColors.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Dream date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isDatePickerPresented = false }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dreamName: String {
        let trimmedName = goalName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }
        if selectedDream == .custom {
            return "your dream"
        }
        return selectedDream?.label ?? "your dream"
    }

    private var titleText: String {
        if selectedDream == .custom && goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name your dream."
        }
        return "Shape \(dreamName)."
    }

    private var nameFieldTitle: String {
        selectedDream == .custom ? "Dream name" : "Goal name"
    }

    private var namePlaceholder: String {
        selectedDream == .custom ? "My dream" : "Bali trip"
    }

    private func inputCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            content()
        }
        .delaydCard()
    }

}

private struct GoalDetailsPreviewHost: View {
    @State private var goalName = "Bali trip"
    @State private var goalAmount = "120000"
    @State private var goalDate: Date? = Calendar.current.date(byAdding: .month, value: 12, to: .now)

    var body: some View {
        GoalDetailsScreen(
            goalName: $goalName,
            goalAmount: $goalAmount,
            goalDate: $goalDate,
            selectedDream: .travel
        )
    }
}

#Preview("Light") {
    GoalDetailsPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    GoalDetailsPreviewHost()
        .preferredColorScheme(.dark)
}
