import Foundation

enum GoalFeasibility {
    struct Result: Equatable {
        let isPossible: Bool
        let message: String
    }

    static func evaluate(
        targetAmount: Double,
        protectedAmount: Double,
        monthlyTarget: Double,
        deadline: Date?,
        currencyCode: String
    ) -> Result? {
        guard targetAmount > 0, monthlyTarget > 0, let deadline else { return nil }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let targetDay = calendar.startOfDay(for: deadline)
        let daysLeft = calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0
        guard daysLeft > 0 else {
            return Result(
                isPossible: false,
                message: "This date is too close. Extend the date or protect the full amount now."
            )
        }

        let remaining = max(targetAmount - protectedAmount, 0)
        guard remaining > 0 else {
            return Result(isPossible: true, message: "Already fully protected.")
        }

        let monthsLeft = max(Double(daysLeft) / 30.4375, 0.03)
        let possibleByDeadline = protectedAmount + (monthlyTarget * monthsLeft)

        if possibleByDeadline + 0.5 >= targetAmount {
            let dateText = deadline.formatted(.dateTime.day().month(.abbreviated).year())
            return Result(
                isPossible: true,
                message: "On pace: \(CurrencyFormatter.format(monthlyTarget, currencyCode: currencyCode))/month can reach this by \(dateText)."
            )
        }

        let requiredMonthly = ceil(remaining / monthsLeft)
        let monthlyGap = max(requiredMonthly - monthlyTarget, 0)
        let dateText = deadline.formatted(.dateTime.day().month(.abbreviated).year())

        return Result(
            isPossible: false,
            message: "To reach by \(dateText), protect \(CurrencyFormatter.format(requiredMonthly, currencyCode: currencyCode))/month. Increase by \(CurrencyFormatter.format(monthlyGap, currencyCode: currencyCode))/month or extend the date."
        )
    }
}

