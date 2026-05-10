import SwiftData
import SwiftUI

struct CreateGoalSheet: View {
    let editingGoal: PlanGoal?
    let onClose: () -> Void
    let onCreate: (PlanGoal) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: CreateGoalField?
    @State private var selectedCategory: GoalCategory
    @State private var goalName: String
    @State private var targetAmount: String
    @State private var deadline: Date
    @State private var noDeadline: Bool
    @State private var monthlyTarget: Double = 10_000
    @State private var currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode
    @State private var isOffPaceConfirmationPresented = false
    @State private var isDatePickerPresented = false

    private enum CreateGoalField { case name, amount }

    init(
        editingGoal: PlanGoal? = nil,
        onClose: @escaping () -> Void = {},
        onCreate: @escaping (PlanGoal) -> Void = { _ in }
    ) {
        self.editingGoal = editingGoal
        self.onClose = onClose
        self.onCreate = onCreate
        _selectedCategory = State(initialValue: editingGoal?.category ?? .travel)
        _goalName = State(initialValue: editingGoal?.name ?? "Bali trip")
        _targetAmount = State(initialValue: editingGoal.map { "\(Int($0.targetAmount))" } ?? "120000")
        let defaultDeadline = Calendar.current.date(byAdding: .month, value: 10, to: .now) ?? .now
        _deadline = State(initialValue: defaultDeadline)
        _noDeadline = State(initialValue: editingGoal.map { $0.daysRemaining == 0 } ?? false)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    Text("What are you saving for?")
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .padding(.top, AppSpacing.md)

                    CreateGoalCategoryRail(selectedCategory: $selectedCategory)
                        .padding(.vertical, AppSpacing.xs)

                    detailCards
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)

            PrimaryButton(editingGoal == nil ? "Create Goal" : "Save Changes") {
                saveTapped()
            }
            .disabled(!canCreate)
            .opacity(canCreate ? 1 : 0.48)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
            .background(AppColors.background(for: colorScheme))
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
        .task {
            let settings = await SettingsRepository(modelContainer: modelContext.container).fetchSnapshot()
            monthlyTarget = settings.monthlySavingsTarget
            currencyCode = settings.defaultCurrency
        }
        .onChange(of: selectedCategory) { oldValue, newValue in
            guard editingGoal == nil else { return }
            let trimmed = goalName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || defaultGoalNames.contains(trimmed) || trimmed == oldValue.defaultGoalName {
                goalName = newValue.defaultGoalName
            }
        }
        .sheet(isPresented: $isDatePickerPresented) {
            datePickerSheet
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .font(.system(size: 15, weight: .semibold))
            }
        }
        .confirmationDialog(
            "This goal is off pace",
            isPresented: $isOffPaceConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Edit Goal", role: .cancel) {}
            Button("Save Anyway") {
                onCreate(makeGoal())
            }
        } message: {
            Text(offPaceConfirmationMessage)
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                DatePicker("Target date", selection: $deadline, displayedComponents: .date)
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
            .navigationTitle("Target date")
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

    private var topBar: some View {
        ZStack {
            Text(editingGoal == nil ? "Create Goal" : "Edit Goal")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .frame(width: 36, height: 36)
                        .background(AppColors.surface(for: colorScheme), in: Circle())
                        .overlay {
                            Circle().stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    private var detailCards: some View {
        VStack(spacing: AppSpacing.md) {
            inputCard(title: "Goal name") {
                TextField("Bali trip", text: $goalName)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .name)
                    .onSubmit { focusedField = .amount }
            }

            inputCard(title: "Target amount") {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    Text(CurrencyFormatter.symbol(for: currencyCode))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                    TextField("120000", text: $targetAmount)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .amount)
                        .onChange(of: targetAmount) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                targetAmount = filtered
                            }
                        }
                }

                if focusedField == .amount {
                    Button("Done editing") {
                        focusedField = nil
                    }
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.purplePrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: Capsule())
                    .buttonStyle(.plain)
                }
            }

            inputCard(title: "Deadline") {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Button {
                        focusedField = nil
                        isDatePickerPresented = true
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "calendar")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.purplePrimary)

                            Text(deadline.formatted(.dateTime.day().month(.wide).year()))
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
                    .disabled(noDeadline)
                    .opacity(noDeadline ? 0.45 : 1)

                    Toggle("I'll figure it out later", isOn: $noDeadline)
                        .font(AppTypography.callout)
                        .tint(AppColors.purplePrimary)
                }
            }

            if let feasibility = feasibilityResult {
                feasibilityCard(feasibility)
            }
        }
    }

    private var canCreate: Bool {
        !goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amountValue > 0
    }

    private var amountValue: Double {
        Double(targetAmount.filter { $0.isNumber || $0 == "." }) ?? 0
    }

    private var feasibilityResult: GoalFeasibility.Result? {
        GoalFeasibility.evaluate(
            targetAmount: amountValue,
            protectedAmount: editingGoal?.currentAmount ?? 0,
            monthlyTarget: monthlyTarget,
            deadline: noDeadline ? nil : deadline,
            currencyCode: currencyCode
        )
    }

    private var offPaceConfirmationMessage: String {
        feasibilityResult?.message ?? "Increase the monthly target, extend the date, or save this goal anyway."
    }

    private func saveTapped() {
        focusedField = nil

        if let feasibilityResult, !feasibilityResult.isPossible {
            isOffPaceConfirmationPresented = true
            return
        }

        onCreate(makeGoal())
    }

    private func feasibilityCard(_ result: GoalFeasibility.Result) -> some View {
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

    private func makeGoal() -> PlanGoal {
        // When editing, preserve the original `id` + `currentAmount` so the
        // repository update lands on the right row and progress doesn't reset.
        let days = noDeadline ? 0 : max(1, Calendar.current.dateComponents([.day], from: .now, to: deadline).day ?? 1)
        let current = editingGoal?.currentAmount ?? 0
        let progress = amountValue > 0 ? min(max(current / amountValue, 0), 1) : 0
        return PlanGoal(
            id: editingGoal?.id ?? UUID(),
            name: goalName,
            category: selectedCategory,
            currentAmount: current,
            targetAmount: amountValue,
            progress: progress,
            daysRemaining: days
        )
    }

    private func inputCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            content()
        }
        .delaydCard()
    }

    private var defaultGoalNames: Set<String> {
        Set(GoalCategory.pickerPresets.map(\.defaultGoalName))
    }
}

private extension GoalCategory {
    var defaultGoalName: String {
        switch self {
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
        case .custom: "My dream"
        }
    }
}

private struct CreateGoalCategoryRail: View {
    @Binding var selectedCategory: GoalCategory
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(GoalCategory.pickerPresets) { category in
                    Button {
                        withAnimation(AppMotion.forwardProgress) {
                            selectedCategory = category
                        }
                    } label: {
                        categoryCell(category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, AppSpacing.xs)
        }
        .scrollClipDisabled()
    }

    private func categoryCell(_ category: GoalCategory) -> some View {
        let isSelected = selectedCategory == category

        return VStack(spacing: AppSpacing.xs) {
            Image(category.illustrationAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .background(category.backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.purplePrimary, lineWidth: isSelected ? 2 : 0)
                }

            Text(category.label)
                .font(AppTypography.captionMedium)
                .foregroundStyle(isSelected ? AppColors.purplePrimary : AppColors.textSecondary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(width: 84, height: 96)
        .background(
            isSelected ? AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.20 : 1) : AppColors.card(for: colorScheme),
            in: RoundedRectangle(cornerRadius: AppRadius.lg)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(isSelected ? AppColors.purplePrimary.opacity(0.32) : AppColors.border(for: colorScheme), lineWidth: 1)
        }
        .scaleEffect(isSelected ? 1.02 : 1)
    }
}

private struct CreateGoalSheetPreviewHost: View {
    @State private var isPresented = true

    var body: some View {
        ZStack {
            AppColors.backgroundLight.ignoresSafeArea()
            Text("Create Goal")
        }
        .sheet(isPresented: $isPresented) {
            CreateGoalSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview("Create Goal Sheet") {
    CreateGoalSheetPreviewHost()
        .preferredColorScheme(.light)
}

#Preview("Create Goal Content Dark") {
    CreateGoalSheet()
        .preferredColorScheme(.dark)
}

#Preview("Create Goal Edge") {
    CreateGoalSheet()
        .dynamicTypeSize(.accessibility2)
        .preferredColorScheme(.light)
}
