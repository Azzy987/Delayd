import Foundation
import SwiftData

struct DreamBoostImpact: Equatable {
    let amount: Double
    let daysCloser: Int
    let affectedGoal: GoalSnapshot
    let previousProgress: Double
    let newProgress: Double
    let previousAmount: Double
    let newAmount: Double
    let location: DreamSavingsLocation
    let currencyCode: String
    let previousTargetDate: Date?
    let improvedTargetDate: Date?
}

@ModelActor
actor DreamContributionRepository {
    func create(
        amount: Double,
        location: DreamSavingsLocation,
        note: String? = nil,
        linkedGoalId: UUID,
        occurredAt: Date,
        monthlySavingsTarget: Double,
        currencyCode: String
    ) async -> DreamBoostImpact? {
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        guard let goal = goals.first(where: { $0.id == linkedGoalId }) else { return nil }

        let previousAmount = goal.currentAmount
        let previousProgress = progress(for: previousAmount, target: goal.targetAmount)
        let newAmount = min(goal.targetAmount, goal.currentAmount + amount)
        let newProgress = progress(for: newAmount, target: goal.targetAmount)
        let daysCloser = daysMovedCloser(amount: amount, goal: goal, previousAmount: previousAmount, monthlySavingsTarget: monthlySavingsTarget)
        let improvedDate = goal.targetDate.flatMap {
            Calendar.current.date(byAdding: .day, value: -daysCloser, to: $0)
        }

        let contribution = DreamContribution(
            amount: amount,
            location: location,
            note: note,
            occurredAt: occurredAt,
            linkedGoal: goal
        )
        modelContext.insert(contribution)

        goal.currentAmount = newAmount
        goal.touch()

        save()
        refreshWidget(goal: goal)

        return DreamBoostImpact(
            amount: amount,
            daysCloser: daysCloser,
            affectedGoal: GoalSnapshot(goal: goal),
            previousProgress: previousProgress,
            newProgress: newProgress,
            previousAmount: previousAmount,
            newAmount: newAmount,
            location: location,
            currencyCode: currencyCode,
            previousTargetDate: goal.targetDate,
            improvedTargetDate: improvedDate
        )
    }

    func fetchAllSnapshots(in interval: DateInterval?) async -> [DreamContributionSnapshot] {
        let descriptor = FetchDescriptor<DreamContribution>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        let contributions = (try? modelContext.fetch(descriptor)) ?? []

        guard let interval else {
            return contributions.map(DreamContributionSnapshot.init(contribution:))
        }

        return contributions
            .filter { interval.contains($0.occurredAt) }
            .map(DreamContributionSnapshot.init(contribution:))
    }

    /// Fetch every contribution attached to a specific goal, newest first.
    /// Used by `GoalDetailView`'s "Saved for this dream" section so it can
    /// render the per-goal contribution log without filtering the full list
    /// in memory on the view side.
    func fetchSnapshots(forGoalId goalId: UUID) async -> [DreamContributionSnapshot] {
        let descriptor = FetchDescriptor<DreamContribution>(
            sortBy: [SortDescriptor(\.occurredAt, order: .reverse)]
        )
        let contributions = (try? modelContext.fetch(descriptor)) ?? []
        return contributions
            .filter { $0.linkedGoal?.id == goalId }
            .map(DreamContributionSnapshot.init(contribution:))
    }

    /// Permanently delete a contribution and reverse its impact on the
    /// linked goal's `currentAmount`. Used by the "Saved" history sheet's
    /// swipe-to-delete (mirrors `ExpenseRepository.delete(id:)`).
    func delete(id: UUID) async {
        let descriptor = FetchDescriptor<DreamContribution>(
            predicate: #Predicate { $0.id == id }
        )
        guard let contribution = (try? modelContext.fetch(descriptor))?.first else { return }
        let amount = contribution.amount
        let goal = contribution.linkedGoal
        modelContext.delete(contribution)
        if let goal {
            goal.currentAmount = max(goal.currentAmount - amount, 0)
            goal.touch()
        }
        save()
        if let goal { refreshWidget(goal: goal) }
    }

    private func daysMovedCloser(amount: Double, goal: Goal, previousAmount: Double, monthlySavingsTarget: Double) -> Int {
        if let targetDate = goal.targetDate {
            let today = Calendar.current.startOfDay(for: .now)
            let targetDay = Calendar.current.startOfDay(for: targetDate)
            let daysRemaining = Calendar.current.dateComponents([.day], from: today, to: targetDay).day ?? 0
            let remainingBefore = max(goal.targetAmount - previousAmount, 0)

            if daysRemaining > 0, remainingBefore > 0 {
                let requiredDaily = max(remainingBefore / Double(daysRemaining), 1)
                return max(1, Int(ceil(amount / requiredDaily)))
            }
        }

        let dailyTarget = max(monthlySavingsTarget, 1) / 30.0
        return max(1, Int(ceil(amount / dailyTarget)))
    }

    private func progress(for amount: Double, target: Double) -> Double {
        min(max(amount / max(target, 1), 0), 1)
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

struct DreamContributionSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let amount: Double
    let location: DreamSavingsLocation
    let occurredAt: Date
    let goalId: UUID?

    nonisolated init(contribution: DreamContribution) {
        id = contribution.id
        amount = contribution.amount
        location = contribution.location
        occurredAt = contribution.occurredAt
        goalId = contribution.linkedGoal?.id
    }
}
