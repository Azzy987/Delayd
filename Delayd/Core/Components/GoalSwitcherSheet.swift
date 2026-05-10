import SwiftUI
import SwiftData

struct GoalSwitcherSheet: View {
    let title: String
    let subtitle: String
    let selectedGoalId: UUID?
    let onSelect: (UUID) -> Void
    let onCreateNew: (() -> Void)?

    @Query(filter: #Predicate<Goal> { !$0.isArchived },
           sort: \Goal.createdAt, order: .reverse)
    private var liveGoals: [Goal]

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        subtitle: String,
        selectedGoalId: UUID?,
        onSelect: @escaping (UUID) -> Void,
        onCreateNew: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.selectedGoalId = selectedGoalId
        self.onSelect = onSelect
        self.onCreateNew = onCreateNew
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "target")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.purplePrimary)
                        .frame(width: 44, height: 44)
                        .background(
                            AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1),
                            in: RoundedRectangle(cornerRadius: AppRadius.md)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        Text(subtitle)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    }
                }

                if liveGoals.isEmpty {
                    VStack(spacing: AppSpacing.sm) {
                        createDreamRow

                        Text("No dreams yet. Create one here to start tracking what spending delays.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            .padding(AppSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.lg)
                                    .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                            }
                    }
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        createDreamRow

                        ForEach(liveGoals) { goal in
                            Button {
                                onSelect(goal.id)
                            } label: {
                                HStack(spacing: AppSpacing.md) {
                                    GoalCategoryIcon(category: goal.category, size: 42)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(goal.name.delaydGoalTitleCased)
                                            .font(AppTypography.bodyMedium)
                                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                        Text(goal.category.label)
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                    }

                                    Spacer()

                                    if selectedGoalId == goal.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(AppColors.purplePrimary)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(
                                    selectedGoalId == goal.id
                                        ? AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.20 : 1)
                                        : AppColors.card(for: colorScheme),
                                    in: RoundedRectangle(cornerRadius: AppRadius.lg)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppRadius.lg)
                                        .stroke(
                                            selectedGoalId == goal.id
                                                ? AppColors.purplePrimary.opacity(0.32)
                                                : AppColors.border(for: colorScheme),
                                            lineWidth: 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    @ViewBuilder
    private var createDreamRow: some View {
        if let onCreateNew {
            Button(action: onCreateNew) {
                HStack(spacing: AppSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                            .fill(AppGradients.heroGradient)
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)
                    .shadow(color: AppColors.purplePrimary.opacity(colorScheme == .dark ? 0.18 : 0.22), radius: 10, x: 0, y: 6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create new dream")
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        Text("Add a goal, then make it the one you protect.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.textTertiary(for: colorScheme))
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.lg)
                        .stroke(AppColors.purplePrimary.opacity(0.22), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
