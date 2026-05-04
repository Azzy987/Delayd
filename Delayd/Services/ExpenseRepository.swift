import Foundation
import SwiftData

@ModelActor
actor ExpenseRepository {
    func fetchRecent(limit: Int) async -> [Expense] {
        var descriptor = FetchDescriptor<Expense>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchByGoal(_ goal: Goal) async -> [Expense] {
        let expenses = await fetchAll(in: nil)
        return expenses.filter { $0.linkedGoal?.id == goal.id }
    }

    func fetchAll(in interval: DateInterval?) async -> [Expense] {
        let descriptor = FetchDescriptor<Expense>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        let expenses = (try? modelContext.fetch(descriptor)) ?? []

        guard let interval else {
            return expenses
        }

        return expenses.filter { interval.contains($0.occurredAt) }
    }

    func fetchRecentSnapshots(limit: Int) async -> [ExpenseSnapshot] {
        let expenses = await fetchRecent(limit: limit)
        return expenses.map(ExpenseSnapshot.init(expense:))
    }

    func fetchAllSnapshots(in interval: DateInterval?) async -> [ExpenseSnapshot] {
        let expenses = await fetchAll(in: interval)
        return expenses.map(ExpenseSnapshot.init(expense:))
    }

    func delayDaysByGoal() async -> [UUID: Int] {
        let events = (try? modelContext.fetch(FetchDescriptor<ImpactEvent>())) ?? []
        return Dictionary(grouping: events, by: \.goalId)
            .mapValues { $0.reduce(0) { $0 + $1.delayDays } }
    }

    func create(
        amount: Double,
        merchant: String?,
        tag: String?,
        note: String?,
        linkedGoal: Goal?,
        occurredAt: Date
    ) async -> Expense {
        let expense = Expense(
            amount: amount,
            merchant: merchant,
            tag: tag,
            note: note,
            occurredAt: occurredAt,
            linkedGoal: linkedGoal
        )
        modelContext.insert(expense)
        save()
        return expense
    }

    func create(
        amount: Double,
        merchant: String?,
        tag: String?,
        note: String?,
        linkedGoalId: UUID?,
        occurredAt: Date
    ) async -> UUID {
        let linkedGoal = linkedGoalId.flatMap { goalId in
            let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
            return goals.first { $0.id == goalId }
        }
        let expense = Expense(
            amount: amount,
            merchant: merchant,
            tag: tag,
            note: note,
            occurredAt: occurredAt,
            linkedGoal: linkedGoal
        )
        modelContext.insert(expense)
        save()
        return expense.id
    }

    func delete(_ expense: Expense) async {
        let goal = expense.linkedGoal
        deleteImpactEvent(expenseId: expense.id)
        modelContext.delete(expense)
        if let goal {
            goal.touch()
        }
        save()
        refreshWidget()
    }

    func delete(id: UUID) async {
        let all = (try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []
        if let expense = all.first(where: { $0.id == id }) {
            let goal = expense.linkedGoal
            deleteImpactEvent(expenseId: id)
            modelContext.delete(expense)
            if let goal {
                goal.touch()
            }
            save()
            refreshWidget()
        }
    }

    func applyImpact(
        goalId: UUID,
        expenseId: UUID,
        delayDays: Int,
        previousProgress: Double,
        newProgress: Double,
        newAmount: Double
    ) async {
        let descriptor = FetchDescriptor<Goal>()
        let goals = (try? modelContext.fetch(descriptor)) ?? []
        guard let goal = goals.first(where: { $0.id == goalId }) else { return }

        goal.touch()

        let event = ImpactEvent(
            expenseId: expenseId,
            goalId: goalId,
            delayDays: delayDays,
            previousProgress: previousProgress,
            newProgress: newProgress
        )
        modelContext.insert(event)
        save()
        refreshWidget(goal: goal)
    }

    func undoImpact(expenseId: UUID, goalId: UUID, previousAmount: Double) async {
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        if let goal = goals.first(where: { $0.id == goalId }) {
            goal.touch()
            deleteImpactEvent(expenseId: expenseId)
        }

        let expenses = (try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []
        if let expense = expenses.first(where: { $0.id == expenseId }) {
            modelContext.delete(expense)
        }

        save()
        refreshWidget()
    }

    private func save() {
        try? modelContext.save()
    }

    private func deleteImpactEvent(expenseId: UUID) {
        let events = (try? modelContext.fetch(FetchDescriptor<ImpactEvent>())) ?? []
        for event in events where event.expenseId == expenseId {
            modelContext.delete(event)
        }
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
        let progress = goal.targetAmount > 0 ? goal.currentAmount / goal.targetAmount : 0
        let savedAmount = goal.currentAmount

        Task { @MainActor in
            DelaydWidgetSync.refresh(
                goalName: goalName,
                goalEmoji: goalEmoji,
                progress: progress,
                daysDelayed: delayedDays,
                savedAmount: savedAmount
            )
        }
    }
}

struct ExpenseSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let amount: Double
    let merchant: String?
    let tag: String?
    let occurredAt: Date
    let goalId: UUID?
    let goalName: String?
    let goalCategory: GoalCategory?

    var displayName: String {
        merchant ?? tag ?? "Expense"
    }

    nonisolated init(expense: Expense) {
        id = expense.id
        amount = expense.amount
        merchant = expense.merchant
        tag = expense.tag
        occurredAt = expense.occurredAt
        goalId = expense.linkedGoal?.id
        goalName = expense.linkedGoal?.name
        goalCategory = expense.linkedGoal?.category
    }
}
