import SwiftUI
import SwiftData

struct QuickLogSheet: View {
    @State private var viewModel: QuickLogViewModel
    @State private var isDatePickerPresented = false
    @State private var isKeypadVisible = true
    @State private var isHardModeConfirmationPresented = false
    @State private var isProUnlocked = ProEntitlementService.isUnlocked
    @FocusState private var isCustomTagFocused: Bool

    let onClose: () -> Void
    let onLogged: (DelayImpact) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    private let hapticService = HapticService()

    @MainActor
    init(
        viewModel: QuickLogViewModel? = nil,
        onClose: @escaping () -> Void = {},
        onLogged: @escaping (DelayImpact) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel ?? QuickLogViewModel())
        self.onClose = onClose
        self.onLogged = onLogged
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.sm) {
                    linkedGoalCard
                    amountCard
                    tagCard
                    dateCard
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 0) {
                keypadHeader

                if isKeypadVisible {
                    NumericKeypad(
                        text: $viewModel.amountText,
                        keyHeight: 42,
                        keySpacing: 8,
                        horizontalPadding: AppSpacing.lg,
                        verticalPadding: AppSpacing.sm,
                        digitFontSize: 22,
                        showsBackground: false,
                        onKeyTap: { hapticService.playLightImpact() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                logButton
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.xs)
                    .padding(.bottom, AppSpacing.md)
            }
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 24
                )
                .fill(AppColors.card(for: colorScheme))
                .ignoresSafeArea(edges: .bottom)
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 24
                )
            )
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
        .interactiveDismissDisabled(viewModel.isLogging)
        .task {
            hapticService.playLightImpact()
            await viewModel.load(modelContainer: modelContext.container)
        }
        .onChange(of: isCustomTagFocused) { _, isFocused in
            guard isFocused else { return }
            withAnimation(AppMotion.sheetPresentation) {
                isKeypadVisible = false
            }
        }
        .sheet(isPresented: $isDatePickerPresented) {
            datePickerSheet
                .delaydPageSheet(detents: [.medium])
        }
        .confirmationDialog(
            hardModeTitle,
            isPresented: $isHardModeConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Log Anyway", role: .destructive) {
                submitLog()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(hardModeMessage)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("Add Expense")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            HStack {
                Button {
                    closeSheet()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .frame(width: 36, height: 36)
                        .background(AppColors.surface(for: colorScheme), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLogging)

                Spacer()
            }
        }
    }

    // MARK: - Linked goal

    private var linkedGoalCard: some View {
        HStack(spacing: AppSpacing.md) {
            GoalCategoryIcon(category: viewModel.selectedGoal.category)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Linked to")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                Text(viewModel.selectedGoal.name.delaydGoalTitleCased)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: AppSpacing.sm)

            // Menu instead of a sheet: per AGENTS.md "Simple selectors should
            // not become custom bottom sheets" — a small list of goals fits
            // a native picker, scrolls naturally if there are many, and the
            // user can see every option without resizing a sheet.
            Menu {
                ForEach(viewModel.goals) { goal in
                    Button {
                        viewModel.selectGoal(goal)
                        hapticService.playLightImpact()
                    } label: {
                        if goal == viewModel.selectedGoal {
                            Label(goal.name.delaydGoalTitleCased, systemImage: "checkmark")
                        } else {
                            Text("\(goal.emoji)  \(goal.name.delaydGoalTitleCased)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Change")
                        .font(AppTypography.callout)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppColors.purplePrimary)
            }
            .disabled(viewModel.isLogging || viewModel.goals.count <= 1)
            .opacity(viewModel.goals.count <= 1 ? 0.45 : 1)
        }
        .quickLogCard(colorScheme: colorScheme)
    }

    // MARK: - Amount (display only; keypad drives it)

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Amount")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(CurrencyFormatter.symbol(for: viewModel.currencyCode))
                    .font(.system(size: 38, weight: .bold, design: .default))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                Text(displayAmount)
                    .font(.system(size: 38, weight: .bold, design: .default))
                    .foregroundStyle(
                        viewModel.amountText.isEmpty
                            ? AppColors.textTertiary(for: colorScheme)
                            : AppColors.textPrimary(for: colorScheme)
                    )
                    .minimumScaleFactor(0.48)
                    .lineLimit(1)

                BlinkingCaret()
                    .frame(width: 2, height: 30)
                    .foregroundStyle(AppColors.purplePrimary)
            }

            if let coachCopy {
                Text(coachCopy)
                    .font(AppTypography.callout)
                    .foregroundStyle(isProUnlocked ? AppColors.purplePrimary : AppColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .quickLogCard(colorScheme: colorScheme)
        .contentShape(Rectangle())
        .onTapGesture {
            isCustomTagFocused = false
            withAnimation(AppMotion.sheetPresentation) {
                isKeypadVisible = true
            }
        }
    }

    private var displayAmount: String {
        viewModel.amountText.isEmpty ? "0" : viewModel.amountText
    }

    private var coachCopy: String? {
        viewModel.delayCoachCopy(isProUnlocked: isProUnlocked)
    }

    // MARK: - Tag (chips with dismiss)

    private var tagCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Tag")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(viewModel.tags) { tag in
                            let isSelected = viewModel.selectedTag == tag && viewModel.customTagTitle.isEmpty
                            Button {
                                viewModel.selectTag(tag)
                                isCustomTagFocused = false
                                hapticService.playLightImpact()
                            } label: {
                                QuickLogTagChip(
                                    title: tag.title,
                                    symbol: symbol(for: tag),
                                    isSelected: isSelected
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isLogging)
                        }
                    }
                    .padding(.vertical, 2)
                }

                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textTertiary(for: colorScheme))

                    TextField("Other expense", text: $viewModel.customTagTitle)
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isCustomTagFocused)
                        .onSubmit {
                            isCustomTagFocused = false
                        }
                        .onChange(of: viewModel.customTagTitle) { _, newValue in
                            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                viewModel.clearTag()
                            }
                        }

                    if !viewModel.customTagTitle.isEmpty {
                        Button {
                            viewModel.customTagTitle = ""
                            isCustomTagFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppColors.textTertiary(for: colorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 10)
                .background(AppColors.softSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .quickLogCard(colorScheme: colorScheme)
    }

    // MARK: - Date (single line + calendar button)

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Date")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            Button {
                isDatePickerPresented = true
            } label: {
                HStack {
                    Text(formattedDate(viewModel.expenseDate))
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    Spacer()
                    PhosphorIcon(.calendarBlank, size: 20)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLogging)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .quickLogCard(colorScheme: colorScheme)
    }

    private var datePickerSheet: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Pick a date")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .padding(.top, AppSpacing.md)

            DatePicker(
                "Date",
                selection: $viewModel.expenseDate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.graphical)
            .tint(AppColors.purplePrimary)
            .padding(.horizontal, AppSpacing.md)

            Button {
                isDatePickerPresented = false
            } label: {
                Text("Done")
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
            .background(AppColors.purplePrimary, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Log button

    private var logButton: some View {
        PrimaryButton("Log Expense", isLoading: viewModel.isLogging) {
            if isProUnlocked && viewModel.needsHardModeConfirmation {
                hapticService.playWarning()
                isHardModeConfirmationPresented = true
            } else {
                submitLog()
            }
        }
        .disabled(!viewModel.canLog)
        .opacity(viewModel.canLog ? 1 : 0.48)
    }

    private var hardModeTitle: String {
        guard let impact = viewModel.previewImpact else {
            return "Log this expense?"
        }
        if impact.delayDays <= 0 {
            return "This nudges \(impact.affectedGoal.name.delaydGoalTitleCased) by under 1 day."
        }
        return "This pushes \(impact.affectedGoal.name.delaydGoalTitleCased) by \(impact.delayDays) days."
    }

    private var hardModeMessage: String {
        "Hard-mode prompt: this is a high-delay spend. Log it only if the tradeoff is worth moving the dream further away."
    }

    private func submitLog() {
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard let impact = await viewModel.logExpense() else { return }
            onLogged(impact)
        }
    }

    private var keypadHeader: some View {
        HStack {
            Text("Keypad")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            Spacer()

            Button {
                isCustomTagFocused = false
                withAnimation(AppMotion.sheetPresentation) {
                    isKeypadVisible.toggle()
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(isKeypadVisible ? "Hide" : "Show")
                    Image(systemName: isKeypadVisible ? "keyboard.chevron.compact.down" : "keyboard")
                }
                .font(AppTypography.captionMedium)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.88) : AppColors.purplePrimary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.purplePrimary.opacity(colorScheme == .dark ? 0.28 : 0.10), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isKeypadVisible ? "Hide keypad" : "Show keypad")
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
    }

    private func symbol(for tag: ExpenseTag) -> String {
        switch tag.id.lowercased() {
        case let value where value.contains("dinner") || value.contains("food") || value.contains("dosa") || value.contains("idli") || value.contains("biryani") || value.contains("pizza") || value.contains("burger"):
            return "fork.knife"
        case let value where value.contains("coffee"):
            return "cup.and.saucer.fill"
        case let value where value.contains("shopping"):
            return "bag.fill"
        case let value where value.contains("travel"):
            return "airplane"
        case let value where value.contains("health"):
            return "cross.case.fill"
        default:
            return "creditcard.fill"
        }
    }

    private func closeSheet() {
        onClose()
    }
}

struct BlinkingCaret: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

private struct QuickLogTagChip: View {
    let title: String
    let symbol: String
    let isSelected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 20, height: 20)
                .foregroundStyle(isSelected ? .white : AppColors.purplePrimary)
                .background(
                    isSelected
                        ? AnyShapeStyle(.white.opacity(0.18))
                        : AnyShapeStyle(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1)),
                    in: Circle()
                )

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(isSelected ? .white : AppColors.textPrimary(for: colorScheme))
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 7)
        .background(chipBackground, in: Capsule())
        .overlay {
            Capsule()
                .stroke(
                    isSelected ? Color.clear : AppColors.border(for: colorScheme),
                    lineWidth: 1
                )
        }
        .shadow(
            color: isSelected ? AppColors.purplePrimary.opacity(colorScheme == .dark ? 0.18 : 0.16) : .clear,
            radius: 8,
            x: 0,
            y: 4
        )
    }

    private var chipBackground: some ShapeStyle {
        isSelected
            ? AnyShapeStyle(AppGradients.heroGradient)
            : AnyShapeStyle(AppColors.card(for: colorScheme))
    }
}

private extension View {
    func quickLogCard(colorScheme: ColorScheme) -> some View {
        self
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 14)
            .background(AppColors.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(AppColors.border(for: colorScheme).opacity(colorScheme == .dark ? 0.7 : 0.85), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.16 : 0.045),
                radius: 10,
                x: 0,
                y: 4
            )
    }
}

private struct QuickLogSheetPreviewHost: View {
    @State private var isPresented = true

    var body: some View {
        ZStack {
            AppColors.backgroundLight
                .ignoresSafeArea()

            Text("Quick Log Sheet Preview")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimaryLight)
        }
        .sheet(isPresented: $isPresented) {
            QuickLogSheet(viewModel: .mock(amount: "500"))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview("Sheet Large Detent") {
    QuickLogSheetPreviewHost()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Content Light") {
    QuickLogSheet(viewModel: .mock(amount: "500"))
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Content Dark") {
    QuickLogSheet(viewModel: .mock(amount: "2500"))
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
