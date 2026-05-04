import Foundation
import SwiftData

enum SeedDataService {
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Goal>()
        let existingGoals = (try? modelContext.fetch(descriptor)) ?? []
        guard existingGoals.isEmpty else { return }

        seed(modelContext: modelContext)
    }

    static func reseed(modelContext: ModelContext) {
        wipe(modelContext: modelContext)
        seed(modelContext: modelContext)
    }

    static func wipe(modelContext: ModelContext) {
        try? modelContext.delete(model: DreamContribution.self)
        try? modelContext.delete(model: ImpactEvent.self)
        try? modelContext.delete(model: Expense.self)
        try? modelContext.delete(model: Goal.self)
        try? modelContext.delete(model: UserSettings.self)
        try? modelContext.save()
    }

    static func stats(modelContext: ModelContext) -> String {
        let goals = ((try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []).count
        let expenses = ((try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []).count
        let contributions = ((try? modelContext.fetch(FetchDescriptor<DreamContribution>())) ?? []).count
        let events = ((try? modelContext.fetch(FetchDescriptor<ImpactEvent>())) ?? []).count
        return "\(goals) goals • \(expenses) impacts • \(contributions) protected • \(events) audit events"
    }

    static func seed(modelContext: ModelContext) {
        let now = Date()
        let goal = Goal(
            name: "Bali trip",
            emoji: GoalCategory.travel.emoji,
            categoryRawValue: GoalCategory.travel.rawValue,
            targetAmount: 120_000,
            currentAmount: 25_000,
            deadline: Calendar.current.date(byAdding: .month, value: 8, to: now),
            createdAt: Calendar.current.date(byAdding: .day, value: -12, to: now) ?? now,
            updatedAt: now
        )

        let settings = UserSettings(
            monthlySavingsTarget: 10_000,
            hapticsEnabled: true,
            notificationsEnabled: false,
            onboardingCompleted: false,
            defaultGoalId: goal.id
        )

        modelContext.insert(goal)
        modelContext.insert(settings)

        let samples: [(Double, String, String, Int)] = [
            (250, "Blue Tokai Coffee", "Coffee", 0),
            (650, "Lunch with team", "Dinner", 0),
            (340, "Cab ride", "Travel", 0),
            (1_900, "Headphones", "Shopping", -1),
            (600, "Course add-on", "Education", -1),
            (280, "Movie night", "Health", -3),
            (500, "Dinner out", "Dinner", -3),
            (2_500, "Weekend shopping", "Shopping", -6)
        ]

        let calculator = DelayCalculator()

        for sample in samples {
            let occurredAt = Calendar.current.date(byAdding: .day, value: sample.3, to: now) ?? now
            let previousProgress = goal.currentAmount / goal.targetAmount
            let impact = calculator.calculateDelay(expenseAmount: sample.0, goal: goal, monthlyTarget: settings.monthlySavingsTarget)
            let expense = Expense(
                amount: sample.0,
                merchant: sample.1,
                tag: sample.2,
                occurredAt: occurredAt,
                createdAt: occurredAt,
                updatedAt: occurredAt,
                linkedGoal: goal
            )
            let event = ImpactEvent(
                expenseId: expense.id,
                goalId: goal.id,
                delayDays: impact.delayDays,
                previousProgress: previousProgress,
                newProgress: impact.newProgress,
                calculatedAt: occurredAt
            )
            modelContext.insert(expense)
            modelContext.insert(event)
        }

        try? modelContext.save()
    }
}
