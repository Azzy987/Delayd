import SwiftUI
import SwiftData

struct HistoryView: View {
    @State private var viewModel: HistoryViewModel
    @State private var isGoalFilterPresented = false
    @State private var isRangeFilterPresented = false
    @State private var selectedImpact: HistoryImpact?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.iPadContentInset) private var hInset
    let refreshToken: Int

    @MainActor
    init(viewModel: HistoryViewModel? = nil, refreshToken: Int = 0) {
        _viewModel = State(initialValue: viewModel ?? HistoryViewModel())
        self.refreshToken = refreshToken
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    compactHeader
                    filterBar

                    if viewModel.isEmpty {
                        EmptyStateCard(
                            systemImage: "clock",
                            assetImageName: "ImpactReveal",
                            title: "No impacts logged",
                            description: "Each logged expense will appear here as time moved away from a goal."
                        )
                    } else {
                        ForEach(viewModel.sections) { section in
                            daySection(section)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg + hInset)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, 96)
            }
            .background(AppColors.background(for: colorScheme))
            .navigationBarHidden(true)
        }
        .task(id: refreshToken) {
            await viewModel.load(modelContainer: modelContext.container)
        }
        .sheet(isPresented: $isGoalFilterPresented) {
            HistoryGoalFilterSheet(
                goals: viewModel.availableGoals,
                selectedGoalId: viewModel.selectedGoalId,
                onSelect: { goalId in
                    viewModel.selectGoal(goalId)
                    isGoalFilterPresented = false
                }
            )
            .delaydPageSheet(detents: [.height(goalFilterSheetHeight), .medium])
        }
        .sheet(isPresented: $isRangeFilterPresented) {
            HistoryRangeFilterSheet(
                selectedRange: viewModel.selectedRange,
                onSelect: { range in
                    viewModel.selectRange(range)
                    isRangeFilterPresented = false
                }
            )
            .delaydPageSheet(detents: [.height(360), .medium])
        }
        .sheet(item: $selectedImpact) { impact in
            ImpactDetailsSheet(
                impact: impact,
                onDelete: {
                    if let expenseId = impact.expenseId {
                        Task {
                            await viewModel.deleteExpense(id: expenseId, modelContainer: modelContext.container)
                        }
                    }
                }
            )
            .delaydPageSheet(detents: [.height(640), .large])
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("History")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            Text("Every logged expense as time moved away from a goal.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
        }
    }

    private var filterBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                isGoalFilterPresented = true
            } label: {
                filterChip(viewModel.selectedGoalTitle, systemImage: "target")
            }
            .buttonStyle(.plain)

            Button {
                isRangeFilterPresented = true
            } label: {
                filterChip(viewModel.selectedRangeTitle, systemImage: "calendar")
            }
            .buttonStyle(.plain)
        }
    }

    private func filterChip(_ title: String, systemImage: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
        }
        .font(AppTypography.captionMedium)
        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private var goalFilterSheetHeight: CGFloat {
        min(520, max(260, CGFloat(viewModel.availableGoals.count + 1) * 72 + 132))
    }

    private func daySection(_ section: HistoryDaySection) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(section.title)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                Text(section.summaryText)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            }

            VStack(spacing: AppSpacing.sm) {
                ForEach(section.impacts) { impact in
                    Button {
                        selectedImpact = impact
                    } label: {
                        ExpenseRow(
                            category: impact.category,
                            expenseIconSystemImage: impact.expenseIconSystemImage,
                            merchantName: impact.merchantName,
                            goalName: impact.goalName,
                            delayText: impact.delayText,
                            amountText: impact.amountText
                        )
                        .padding(.horizontal, AppSpacing.cardHorizontalPadding)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                        }
                        .shadow(
                            color: .black.opacity(colorScheme == .dark ? 0.03 : 0.04),
                            radius: 12,
                            x: 0,
                            y: 4
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct HistoryGoalFilterSheet: View {
    let goals: [GoalFilterOption]
    let selectedGoalId: UUID?
    let onSelect: (UUID?) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            sheetHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.sm) {
                    optionRow(
                        icon: .system("target"),
                        title: "All Goals",
                        subtitle: "Show every logged impact",
                        isSelected: selectedGoalId == nil
                    ) {
                        onSelect(nil)
                    }

                    ForEach(goals) { goal in
                        optionRow(
                            icon: .emoji(goal.emoji),
                            title: goal.name,
                            subtitle: "Only this dream",
                            isSelected: selectedGoalId == goal.id
                        ) {
                            onSelect(goal.id)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Filter by goal")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            Text("Choose which dream's delay history to review.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
        }
    }

    private func optionRow(
        icon: FilterIcon,
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                iconView(icon)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.purplePrimary)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(isSelected ? AppColors.purplePrimary.opacity(0.35) : AppColors.border(for: colorScheme), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func iconView(_ icon: FilterIcon) -> some View {
        switch icon {
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: 20))
                .frame(width: 42, height: 42)
                .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.purplePrimary)
                .frame(width: 42, height: 42)
                .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))
        }
    }

    private enum FilterIcon {
        case emoji(String)
        case system(String)
    }
}

private struct HistoryRangeFilterSheet: View {
    let selectedRange: HistoryViewModel.DateRange
    let onSelect: (HistoryViewModel.DateRange) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Filter by time")
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .lineLimit(1)

                    Text("Review recent delay impact without leaving History.")
                        .font(AppTypography.callout)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, AppSpacing.sm)

                VStack(spacing: AppSpacing.sm) {
                    ForEach(HistoryViewModel.DateRange.allCases) { range in
                        Button {
                            onSelect(range)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                PhosphorIcon(.calendarBlank, size: 18)
                                    .foregroundStyle(AppColors.purplePrimary)
                                    .frame(width: 42, height: 42)
                                    .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))

                                Text(range.rawValue)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                                Spacer()

                                if selectedRange == range {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(AppColors.purplePrimary)
                                }
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.lg)
                                    .stroke(selectedRange == range ? AppColors.purplePrimary.opacity(0.35) : AppColors.border(for: colorScheme), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }
}

#Preview("History Loaded Light") {
    HistoryView(viewModel: .mock())
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("History Loaded Dark") {
    HistoryView(viewModel: .mock())
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}

#Preview("History Empty") {
    HistoryView(viewModel: .empty())
        .modelContainer(PreviewContainer.empty)
        .preferredColorScheme(.light)
}

#Preview("History Goal Filter Sheet") {
    HistoryGoalFilterSheet(
        goals: [
            GoalFilterOption(id: UUID(), name: "Bali trip", emoji: GoalCategory.travel.emoji),
            GoalFilterOption(id: UUID(), name: "New car", emoji: GoalCategory.vehicle.emoji),
            GoalFilterOption(id: UUID(), name: "Gaming setup", emoji: GoalCategory.gaming.emoji)
        ],
        selectedGoalId: nil,
        onSelect: { _ in }
    )
    .preferredColorScheme(.light)
}

#Preview("History Range Filter Sheet Dark") {
    HistoryRangeFilterSheet(
        selectedRange: .last30Days,
        onSelect: { _ in }
    )
    .preferredColorScheme(.dark)
}
