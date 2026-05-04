import SwiftUI
import SwiftData

/// Full-size bottom sheet that lists every Protect-Dream contribution the
/// user has logged, grouped by day. Reached by tapping the "Saved this
/// month" card on Home and (in a smaller embedded form) from
/// `GoalDetailView`'s "Saved for this dream" section.
///
/// Data comes from `DreamContributionRepository.fetchAllSnapshots(in:)`. We
/// deliberately fetch *all* contributions and group on the client because
/// the dataset is small (one row per Protect-Dream tap) and an in-memory
/// filter keeps the UI snappy even when the user wants to flip across goals.
///
/// Mirrors the visual language of `HistoryView` (day section header → grey
/// surface card → row per entry) so the two ledger surfaces feel like
/// halves of the same idea.
struct SavedHistorySheet: View {
    @State private var viewModel: SavedHistoryViewModel
    @State private var isGoalFilterPresented = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    let onClose: () -> Void
    let onAddProtection: (() -> Void)?

    @MainActor
    init(
        viewModel: SavedHistoryViewModel? = nil,
        onClose: @escaping () -> Void = {},
        onAddProtection: (() -> Void)? = nil
    ) {
        _viewModel = State(initialValue: viewModel ?? SavedHistoryViewModel())
        self.onClose = onClose
        self.onAddProtection = onAddProtection
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    summaryCard

                    filterBar

                    if viewModel.isEmpty {
                        EmptyStateCard(
                            systemImage: "checkmark.shield.fill",
                            assetImageName: "ImpactReveal",
                            title: "Nothing protected yet",
                            description: "Each Protect Dream entry will appear here with the date and the dream it pushed forward."
                        )
                    } else {
                        ForEach(viewModel.sections) { section in
                            daySection(section)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.background(for: colorScheme))
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
        .task {
            await viewModel.load(modelContainer: modelContext.container)
        }
        .sheet(isPresented: $isGoalFilterPresented) {
            SavedGoalFilterSheet(
                goals: viewModel.availableGoals,
                selectedGoalId: viewModel.selectedGoalId,
                onSelect: { goalId in
                    viewModel.selectGoal(goalId)
                    isGoalFilterPresented = false
                }
            )
            .delaydPageSheet(detents: [.height(420), .medium])
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("Saved")
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
                            Circle()
                                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")

                Spacer()

                if let onAddProtection {
                    Button {
                        onAddProtection()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("Protect")
                                .font(AppTypography.captionMedium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 8)
                        .background(AppGradients.heroGradient, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Protect Dream")
                }
            }
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.softPositiveBackground.opacity(colorScheme == .dark ? 0.22 : 1))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.positive)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.summaryTitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                Text(viewModel.summaryAmountText)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.positive)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("Entries")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                Text("\(viewModel.totalEntryCount)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                isGoalFilterPresented = true
            } label: {
                filterChip(viewModel.selectedGoalTitle, systemImage: "target")
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

    // MARK: - Day section

    private func daySection(_ section: SavedDaySection) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(section.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                Spacer()
                Text(section.totalText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.positive)
            }

            VStack(spacing: 0) {
                ForEach(Array(section.entries.enumerated()), id: \.element.id) { idx, entry in
                    contributionRow(entry)
                        .padding(.vertical, AppSpacing.sm)

                    if idx < section.entries.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
            }
        }
    }

    private func contributionRow(_ entry: SavedHistoryEntry) -> some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.softPositiveBackground.opacity(colorScheme == .dark ? 0.22 : 1))
                    .frame(width: 38, height: 38)
                Image(systemName: entry.locationSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.positive)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.goalName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .lineLimit(1)
                Text(entry.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(entry.amountText)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.positive)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task {
                    await viewModel.delete(id: entry.id, modelContainer: modelContext.container)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private struct SavedGoalFilterSheet: View {
    let goals: [GoalFilterOption]
    let selectedGoalId: UUID?
    let onSelect: (UUID?) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Filter by dream")
                .font(AppTypography.title)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)

            VStack(spacing: 0) {
                filterRow(
                    title: "All Dreams",
                    subtitle: "Show every saved entry",
                    emoji: "✨",
                    isSelected: selectedGoalId == nil
                ) {
                    onSelect(nil)
                }

                Divider()

                ForEach(Array(goals.enumerated()), id: \.element.id) { idx, goal in
                    filterRow(
                        title: goal.name,
                        subtitle: "Only this dream",
                        emoji: goal.emoji,
                        isSelected: selectedGoalId == goal.id
                    ) {
                        onSelect(goal.id)
                    }
                    if idx < goals.count - 1 {
                        Divider()
                    }
                }
            }
            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer(minLength: AppSpacing.lg)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    private func filterRow(
        title: String,
        subtitle: String,
        emoji: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Text(emoji)
                    .font(.system(size: 20))
                    .frame(width: 30)

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
                        .font(.system(size: 18))
                        .foregroundStyle(AppColors.purplePrimary)
                }
            }
            .padding(AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Saved History — populated") {
    SavedHistorySheet(viewModel: .mockPopulated())
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Saved History — empty") {
    SavedHistorySheet(viewModel: .mockEmpty())
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
