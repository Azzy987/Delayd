import SwiftUI
import Observation
import SwiftData

@Observable
final class PlanViewModel {
    var goals: [PlanGoal]

    init(goals: [PlanGoal] = []) {
        self.goals = goals
    }

    var featuredGoal: PlanGoal? {
        goals.first
    }

    var remainingGoals: [PlanGoal] {
        Array(goals.dropFirst())
    }

    var isEmpty: Bool {
        goals.isEmpty
    }

    func addGoal(_ goal: PlanGoal) {
        goals.insert(goal, at: 0)
    }

    func load(modelContainer: ModelContainer) async {
        let repository = GoalRepository(modelContainer: modelContainer)
        let expenseRepository = ExpenseRepository(modelContainer: modelContainer)
        let contributionRepository = DreamContributionRepository(modelContainer: modelContainer)
        let settingsRepository = SettingsRepository(modelContainer: modelContainer)
        let snapshot = await settingsRepository.fetchSnapshot()
        let settings = await settingsRepository.fetch()
        let fetchedGoals = await repository.fetchActive()
        let defaultGoalId = snapshot.defaultGoalId
        let orderedGoals: [Goal]
        if let defaultGoalId,
           let selected = fetchedGoals.first(where: { $0.id == defaultGoalId }) {
            orderedGoals = [selected] + fetchedGoals.filter { $0.id != defaultGoalId }
        } else {
            orderedGoals = fetchedGoals
        }
        let delayedDaysByGoal = await expenseRepository.totalHistoricalDelayDaysByGoal()
        let netStatusByGoal = await contributionRepository.netStatusByGoal(
            totalDelayDaysByGoal: delayedDaysByGoal,
            monthlySavingsTarget: settings.monthlySavingsTarget
        )
        let code = snapshot.defaultCurrency
        goals = orderedGoals.map { goal in
            let net = netStatusByGoal[goal.id] ?? .onPace
            return PlanGoal(
                goal: goal,
                delayedDays: net.delayedDays,
                aheadDays: net.aheadDays,
                currencyCode: code
            )
        }
    }

    func addGoal(_ goal: PlanGoal, modelContainer: ModelContainer) async {
        let repository = GoalRepository(modelContainer: modelContainer)
        let created = await repository.create(
            name: goal.name,
            emoji: goal.category.emoji,
            category: goal.category,
            targetAmount: goal.targetAmount,
            deadline: goal.daysRemaining > 0 ? Calendar.current.date(byAdding: .day, value: goal.daysRemaining, to: .now) : nil
        )
        goals.insert(PlanGoal(goal: created, currencyCode: goal.currencyCode), at: 0)
    }

    func deleteGoal(_ goal: PlanGoal, modelContainer: ModelContainer) async {
        let repository = GoalRepository(modelContainer: modelContainer)
        if let existing = await repository.fetch(id: goal.id) {
            await repository.delete(existing)
        }
        goals.removeAll { $0.id == goal.id }
    }

    /// Persist edits made via `CreateGoalSheet(editingGoal:)`. Mutates the
    /// underlying `Goal` row by `id` and re-emits the matching `PlanGoal` so
    /// the list updates in place.
    func updateGoal(_ goal: PlanGoal, modelContainer: ModelContainer) async {
        let repository = GoalRepository(modelContainer: modelContainer)
        guard let existing = await repository.fetch(id: goal.id) else { return }

        existing.name = goal.name
        existing.emoji = goal.category.emoji
        existing.categoryRawValue = goal.category.rawValue
        existing.targetAmount = goal.targetAmount
        existing.deadline = goal.daysRemaining > 0
            ? Calendar.current.date(byAdding: .day, value: goal.daysRemaining, to: .now)
            : nil

        await repository.update(existing)

        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = PlanGoal(goal: existing, currencyCode: goal.currencyCode)
        }
    }
}

struct PlanGoal: Identifiable, Equatable {
    let id: UUID
    var name: String
    var category: GoalCategory
    var currentAmount: Double
    var targetAmount: Double
    var progress: Double
    var daysRemaining: Int
    var delayedDays: Int
    var aheadDays: Int
    var warningText: String?
    /// ISO 4217 currency code from UserSettings — drives amount formatting.
    var currencyCode: String

    init(
        id: UUID = UUID(),
        name: String,
        category: GoalCategory,
        currentAmount: Double,
        targetAmount: Double,
        progress: Double,
        daysRemaining: Int,
        delayedDays: Int = 0,
        aheadDays: Int = 0,
        warningText: String? = nil,
        currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.currentAmount = currentAmount
        self.targetAmount = targetAmount
        self.progress = progress.isFinite ? min(max(progress, 0), 1) : 0
        self.daysRemaining = daysRemaining
        self.delayedDays = delayedDays
        self.aheadDays = aheadDays
        self.warningText = warningText
        self.currencyCode = currencyCode
    }

    var formattedCurrentAmount: String {
        CurrencyFormatter.format(currentAmount, currencyCode: currencyCode)
    }

    var formattedTargetAmount: String {
        CurrencyFormatter.format(targetAmount, currencyCode: currencyCode)
    }

    var percentageText: String {
        "\(Int((progress * 100).rounded()))%"
    }

    var displayName: String {
        name.delaydGoalTitleCased
    }

    var heroStatus: GoalHeroCard.Status {
        if aheadDays > 0 {
            return .ahead(days: aheadDays)
        }
        return delayedDays > 0 ? .delayed(days: delayedDays) : .onPace
    }

    var timelineSummaryText: String {
        if aheadDays > 0 {
            return "\(aheadDays) \(aheadDays == 1 ? "day" : "days") ahead"
        }
        if delayedDays > 0 {
            return "\(delayedDays) \(delayedDays == 1 ? "day" : "days") delayed"
        }
        return "On pace"
    }

}

extension String {
    var delaydGoalTitleCased: String {
        split(separator: " ", omittingEmptySubsequences: false)
            .map { word in
                guard let first = word.first else { return String(word) }
                return first.uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}

extension PlanGoal {
    init(
        goal: Goal,
        delayedDays: Int = 0,
        aheadDays: Int = 0,
        warningText: String? = nil,
        currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode
    ) {
        let rawProgress = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0
        let progress = rawProgress.isFinite ? min(max(rawProgress, 0), 1) : 0
        let daysRemaining: Int
        if let deadline = goal.deadline {
            daysRemaining = max(0, Calendar.current.dateComponents([.day], from: .now, to: deadline).day ?? 0)
        } else {
            daysRemaining = 0
        }

        self.init(
            id: goal.id,
            name: goal.name,
            category: goal.category,
            currentAmount: goal.currentAmount,
            targetAmount: goal.targetAmount,
            progress: progress,
            daysRemaining: daysRemaining,
            delayedDays: delayedDays,
            aheadDays: aheadDays,
            warningText: warningText,
            currencyCode: currencyCode
        )
    }
}

extension PlanGoal {
    static let mockGoals: [PlanGoal] = [
        PlanGoal(
            name: "House by the Sea",
            category: .home,
            currentAmount: 8_750,
            targetAmount: 17_500,
            progress: 0.50,
            daysRemaining: 184,
            delayedDays: 6,
            warningText: "You're 30% behind schedule"
        ),
        PlanGoal(
            name: "Save for a Car",
            category: .vehicle,
            currentAmount: 275_000,
            targetAmount: 500_000,
            progress: 0.55,
            daysRemaining: 156
        ),
        PlanGoal(
            name: "Save for Education",
            category: .education,
            currentAmount: 50_000,
            targetAmount: 200_000,
            progress: 0.25,
            daysRemaining: 310,
            delayedDays: 4
        ),
        PlanGoal(
            name: "Vacation fund",
            category: .vacation,
            currentAmount: 78_000,
            targetAmount: 120_000,
            progress: 0.65,
            daysRemaining: 82
        ),
        PlanGoal(
            name: "Health Savings",
            category: .savings,
            currentAmount: 90_000,
            targetAmount: 200_000,
            progress: 0.45,
            daysRemaining: 220,
            delayedDays: 2
        )
    ]
}

extension PlanViewModel {
    static func mock() -> PlanViewModel {
        PlanViewModel(goals: PlanGoal.mockGoals)
    }

    static func empty() -> PlanViewModel {
        PlanViewModel(goals: [])
    }
}

#Preview("Plan View Model") {
    Text(PlanViewModel.mock().featuredGoal?.name ?? "No goals")
        .font(AppTypography.bodyMedium)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
