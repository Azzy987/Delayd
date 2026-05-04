import SwiftUI
import SwiftData

struct GoalDetailView: View {
    let goal: PlanGoal
    let onClose: (() -> Void)?
    let onGoalUpdated: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isEditPresented = false
    @State private var isDeleteConfirmPresented = false
    @State private var displayedGoal: PlanGoal
    @State private var savedEntries: [DreamContributionSnapshot] = []
    @State private var currencyCode = CurrencyFormatter.localeDefaultCurrencyCode

    @Query private var linkedExpenses: [Expense]

    init(goal: PlanGoal, onClose: (() -> Void)? = nil, onGoalUpdated: (() -> Void)? = nil) {
        self.goal = goal
        self.onClose = onClose
        self.onGoalUpdated = onGoalUpdated
        _displayedGoal = State(initialValue: goal)
        let goalId = goal.id
        _linkedExpenses = Query(
            filter: #Predicate<Expense> { $0.linkedGoal?.id == goalId },
            sort: \Expense.occurredAt, order: .reverse
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                GoalHeroCard(
                    category: displayedGoal.category,
                    goalName: displayedGoal.displayName,
                    currentAmount: displayedGoal.formattedCurrentAmount,
                    targetAmount: displayedGoal.formattedTargetAmount,
                    progress: CGFloat(displayedGoal.progress),
                    daysRemaining: displayedGoal.daysRemaining,
                    status: displayedGoal.heroStatus
                )

                statsGrid

                SectionHeader("Expenses for this goal")

                if linkedExpenses.isEmpty {
                    Text("No expenses logged yet. Use the + button to log a spend against this goal.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                        .padding(AppSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                        }
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(Array(linkedExpenses.prefix(10).enumerated()), id: \.element.id) { idx, expense in
                            ExpenseRow(
                                category: displayedGoal.category,
                                expenseIconSystemImage: "creditcard.fill",
                                merchantName: expense.merchant ?? expense.tag ?? "Expense",
                                goalName: displayedGoal.displayName,
                                delayText: "",
                                amountText: CurrencyFormatter.formatNegative(expense.amount, currencyCode: displayedGoal.currencyCode)
                            )
                            if idx < min(linkedExpenses.count, 10) - 1 {
                                Divider()
                            }
                        }
                    }
                    .delaydCard()
                }

                SectionHeader("Saved for this dream")

                if savedEntries.isEmpty {
                    Text("No Protect Dream entries yet.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                        .padding(AppSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                        }
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(Array(savedEntries.prefix(10).enumerated()), id: \.element.id) { idx, entry in
                            savedEntryRow(entry)
                            if idx < min(savedEntries.count, 10) - 1 {
                                Divider()
                            }
                        }
                    }
                    .delaydCard()
                }

                SectionHeader("Actions")

                VStack(spacing: AppSpacing.md) {
                    SecondaryButton("Edit Goal", systemImage: "pencil") {
                        isEditPresented = true
                    }

                    Button("Delete Goal") {
                        isDeleteConfirmPresented = true
                    }
                    .buttonStyle(DestructiveButtonStyle())
                }
            }
            .padding(AppSpacing.lg)
            .padding(.bottom, 96)
        }
        .background(AppColors.background(for: colorScheme))
        .navigationTitle(displayedGoal.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share goal")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .font(.system(size: 15, weight: .semibold))
                        .accessibilityLabel("Close goal details")
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share goal")
                }
            }
        }
        .sheet(isPresented: $isEditPresented) {
            CreateGoalSheet(
                editingGoal: displayedGoal,
                onClose: { isEditPresented = false },
                onCreate: { edited in
                    updateGoal(edited)
                }
            )
            .delaydPageSheet(detents: [.large])
        }
        .confirmationDialog(
            "Delete \(displayedGoal.displayName)?",
            isPresented: $isDeleteConfirmPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Goal", role: .destructive) {
                deleteGoal()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the goal and all its linked data.")
        }
        .task(id: displayedGoal.id) {
            await loadSavedEntries()
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.md) {
            statCard(title: "Target", value: displayedGoal.formattedTargetAmount)
            statCard(title: "Saved", value: displayedGoal.formattedCurrentAmount)
            statCard(title: "Days left", value: displayedGoal.daysRemaining > 0 ? "\(displayedGoal.daysRemaining)" : "—")
            statCard(title: "Delayed", value: "\(displayedGoal.delayedDays) day\(displayedGoal.delayedDays == 1 ? "" : "s")")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            Text(value)
                .font(.system(.body, design: .monospaced, weight: .bold))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .delaydCard()
    }

    private func deleteGoal() {
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        if let target = goals.first(where: { $0.id == displayedGoal.id }) {
            modelContext.delete(target)
            try? modelContext.save()
        }
        onGoalUpdated?()
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func updateGoal(_ edited: PlanGoal) {
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        guard let target = goals.first(where: { $0.id == edited.id }) else {
            isEditPresented = false
            return
        }

        target.name = edited.name
        target.emoji = edited.category.emoji
        target.categoryRawValue = edited.category.rawValue
        target.targetAmount = edited.targetAmount
        target.deadline = edited.daysRemaining > 0
            ? Calendar.current.date(byAdding: .day, value: edited.daysRemaining, to: .now)
            : nil
        target.touch()
        try? modelContext.save()
        displayedGoal = edited
        onGoalUpdated?()
        isEditPresented = false
    }

    private func loadSavedEntries() async {
        let settingsRepository = SettingsRepository(modelContainer: modelContext.container)
        let contributionRepository = DreamContributionRepository(modelContainer: modelContext.container)
        async let settings = settingsRepository.fetchSnapshot()
        async let contributions = contributionRepository.fetchSnapshots(forGoalId: displayedGoal.id)
        let settingsSnapshot = await settings
        let contributionSnapshots = await contributions
        currencyCode = settingsSnapshot.defaultCurrency
        savedEntries = contributionSnapshots
    }

    private func savedEntryRow(_ entry: DreamContributionSnapshot) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.softPositiveBackground.opacity(colorScheme == .dark ? 0.22 : 1))
                    .frame(width: 38, height: 38)
                Image(systemName: entry.location.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.positive)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.location.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            }

            Spacer()

            Text(CurrencyFormatter.format(entry.amount, currencyCode: currencyCode))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.positive)
        }
    }

    private var shareText: String {
        "\(displayedGoal.displayName) is \(displayedGoal.percentageText) protected in Delayd. Spending has moved it by \(displayedGoal.delayedDays) days.\n\nGet Delayd: \(AppShare.appLink)"
    }
}

#Preview("Goal Detail Light") {
    NavigationStack {
        GoalDetailView(goal: PlanGoal.mockGoals[0])
    }
    .preferredColorScheme(.light)
}

#Preview("Goal Detail Dark") {
    NavigationStack {
        GoalDetailView(goal: PlanGoal.mockGoals[0])
    }
    .preferredColorScheme(.dark)
}

#Preview("Goal Detail Edge") {
    NavigationStack {
        GoalDetailView(goal: PlanGoal.mockGoals[2])
    }
    .dynamicTypeSize(.accessibility2)
    .preferredColorScheme(.light)
}
