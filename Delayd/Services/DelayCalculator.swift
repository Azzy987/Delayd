import Foundation
import SwiftUI

struct DelayImpact: Equatable {
    let amount: Double
    let delayDays: Int
    let affectedGoal: GoalSnapshot
    let suggestion: String
    let previousProgress: Double
    let newProgress: Double
    let previousAmount: Double
    let newAmount: Double
    let currencyCode: String
    let expenseId: UUID?
}

struct DelayCalculator {
    func calculateDelay(expenseAmount: Double, goal: Goal, monthlyTarget: Double) -> DelayImpact {
        calculateDelay(expenseAmount: expenseAmount, goal: GoalSnapshot(goal: goal), monthlyTarget: monthlyTarget)
    }

    func calculateDelay(expenseAmount: Double, goal: GoalSnapshot, monthlyTarget: Double) -> DelayImpact {
        let safeTarget = max(monthlyTarget, 1)
        let dailyTarget = safeTarget / 30.0
        let delayDays = max(1, Int(ceil(expenseAmount / dailyTarget)))
        let previousProgress = clampedProgress(goal.currentAmount / max(goal.targetAmount, 1))
        // Spending delays the projected timeline, but it does not remove
        // money the user already protected in a piggy bank, bank, locker, etc.
        let newAmount = goal.currentAmount
        let newProgress = clampedProgress(newAmount / max(goal.targetAmount, 1))

        return DelayImpact(
            amount: expenseAmount,
            delayDays: delayDays,
            affectedGoal: goal,
            suggestion: generateSuggestion(amount: expenseAmount, delayDays: delayDays, goal: goal, monthlyTarget: safeTarget),
            previousProgress: previousProgress,
            newProgress: newProgress,
            previousAmount: goal.currentAmount,
            newAmount: newAmount,
            currencyCode: "USD",
            expenseId: nil
        )
    }

    func delayDays(forExpense amount: Decimal, monthlySavingsTarget: Decimal) -> Int {
        let expense = NSDecimalNumber(decimal: amount).doubleValue
        let monthlyTarget = NSDecimalNumber(decimal: monthlySavingsTarget).doubleValue
        let dailyTarget = max(monthlyTarget, 1) / 30.0
        return max(1, Int(ceil(expense / dailyTarget)))
    }

    private func generateSuggestion(amount: Double, delayDays: Int, goal: GoalSnapshot, monthlyTarget: Double) -> String {
        if amount <= monthlyTarget / 20 {
            return "Skipping this 4x/month would put your goal \(delayDays * 4) days closer"
        }

        if amount <= monthlyTarget / 4 {
            let weeklyBudget = max(monthlyTarget / 4, 1)
            let percentage = Int((amount / weeklyBudget * 100).rounded())
            return "This is \(percentage)% of your weekly delay budget"
        }

        if let targetDate = goal.targetDate {
            let slippedDate = Calendar.current.date(byAdding: .day, value: delayDays, to: targetDate) ?? targetDate
            return "Your \(goal.name) just slipped to \(slippedDate.formatted(date: .abbreviated, time: .omitted))"
        }

        return "Your \(goal.name) just moved \(delayDays) days further away"
    }

    private func clampedProgress(_ progress: Double) -> Double {
        min(max(progress, 0), 1)
    }
}

extension DelayImpact {
    func withExpenseId(_ expenseId: UUID) -> DelayImpact {
        DelayImpact(
            amount: amount,
            delayDays: delayDays,
            affectedGoal: affectedGoal,
            suggestion: suggestion,
            previousProgress: previousProgress,
            newProgress: newProgress,
            previousAmount: previousAmount,
            newAmount: newAmount,
            currencyCode: currencyCode,
            expenseId: expenseId
        )
    }

    func withCurrencyCode(_ currencyCode: String) -> DelayImpact {
        DelayImpact(
            amount: amount,
            delayDays: delayDays,
            affectedGoal: affectedGoal,
            suggestion: suggestion,
            previousProgress: previousProgress,
            newProgress: newProgress,
            previousAmount: previousAmount,
            newAmount: newAmount,
            currencyCode: currencyCode,
            expenseId: expenseId
        )
    }
}

extension DelayImpact {
    static let mockSmall = DelayCalculator().calculateDelay(expenseAmount: 150, goal: GoalSnapshot.mockBali, monthlyTarget: 10_000)
    static let mockMedium = DelayCalculator().calculateDelay(expenseAmount: 500, goal: GoalSnapshot.mockBali, monthlyTarget: 10_000)
    static let mockLarge = DelayCalculator().calculateDelay(expenseAmount: 2_500, goal: GoalSnapshot.mockGaming, monthlyTarget: 7_000)
    static let mockEmergency = DelayCalculator().calculateDelay(expenseAmount: 50_000, goal: GoalSnapshot.mockEmergency, monthlyTarget: 8_500)
}

private struct DelayCalculatorPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("$500 delayed \(DelayImpact.mockMedium.affectedGoal.name) by \(DelayImpact.mockMedium.delayDays) days")
                .font(AppTypography.bodyMedium)

            Text(DelayImpact.mockMedium.suggestion)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondaryLight)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
    }
}

#Preview("Delay Calculator") {
    DelayCalculatorPreview()
}
