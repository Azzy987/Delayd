import Foundation
import SwiftData

@ModelActor
actor GoalRepository {
    func fetchActive() async -> [Goal] {
        let goals = await fetchAll()
        return goals.filter { !$0.isArchived }
    }

    func fetchActiveSnapshots() async -> [GoalSnapshot] {
        let goals = await fetchActive()
        return goals.map { goal in
            GoalSnapshot(
                id: goal.id,
                name: goal.name,
                emoji: goal.emoji,
                category: goal.category,
                targetAmount: goal.targetAmount,
                currentAmount: goal.currentAmount,
                targetDate: goal.targetDate
            )
        }
    }

    func fetchAll() async -> [Goal] {
        let descriptor = FetchDescriptor<Goal>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func accrueSavings(monthlyTarget: Double, now: Date = .now) async {
        let dailyTarget = max(monthlyTarget, 1) / 30.0
        let goals = await fetchActive()
        var didChange = false

        for goal in goals where goal.currentAmount < goal.targetAmount {
            let elapsed = now.timeIntervalSince(goal.updatedAt)
            guard elapsed >= 86_400 else { continue }

            let days = floor(elapsed / 86_400)
            let accrued = days * dailyTarget
            goal.currentAmount = min(goal.targetAmount, goal.currentAmount + accrued)
            goal.touch()
            didChange = true
        }

        if didChange {
            save()
            refreshWidget()
        }
    }

    func fetch(id: UUID) async -> Goal? {
        let goals = await fetchAll()
        return goals.first { $0.id == id }
    }

    func create(
        name: String,
        emoji: String,
        category: GoalCategory,
        targetAmount: Double,
        currentAmount: Double = 0,
        deadline: Date?
    ) async -> Goal {
        let goal = Goal(
            name: name,
            emoji: emoji,
            categoryRawValue: category.rawValue,
            targetAmount: targetAmount,
            currentAmount: min(max(currentAmount, 0), targetAmount),
            deadline: deadline
        )
        modelContext.insert(goal)
        save()
        refreshWidget(goal: goal)
        return goal
    }

    func update(_ goal: Goal) async {
        goal.touch()
        save()
        refreshWidget(goal: goal)
    }

    func archive(_ goal: Goal) async {
        goal.isArchived = true
        goal.touch()
        save()
    }

    func delete(_ goal: Goal) async {
        modelContext.delete(goal)
        save()
        refreshWidget()
    }

    private func save() {
        try? modelContext.save()
    }

    private func refreshWidget(goal preferredGoal: Goal? = nil) {
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        let goal = preferredGoal ?? goals.first { !$0.isArchived } ?? goals.first
        guard let goal else { return }

        let events = (try? modelContext.fetch(FetchDescriptor<ImpactEvent>())) ?? []
        let delayedDays = events
            .filter { $0.goalId == goal.id }
            .reduce(0) { $0 + $1.delayDays }

        let goalName = goal.name
        let goalEmoji = goal.emoji
        let goalIllustrationAssetName = goal.category.illustrationAssetName
        let progress = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0
        let savedAmount = goal.currentAmount

        Task { @MainActor in
            DelaydWidgetSync.refresh(
                goalName: goalName,
                goalEmoji: goalEmoji,
                goalIllustrationAssetName: goalIllustrationAssetName,
                progress: progress,
                daysDelayed: delayedDays,
                savedAmount: savedAmount
            )
        }
    }
}
