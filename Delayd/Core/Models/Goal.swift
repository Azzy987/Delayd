import Foundation
import SwiftData

@Model
final class Goal {
    @Attribute(.unique) var id: UUID
    var name: String
    var emoji: String
    var categoryRawValue: String
    var targetAmount: Double
    var currentAmount: Double
    var deadline: Date?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \Expense.linkedGoal)
    var expenses: [Expense]

    @Relationship(deleteRule: .cascade, inverse: \DreamContribution.linkedGoal)
    var contributions: [DreamContribution]

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        categoryRawValue: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        deadline: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isArchived: Bool = false,
        expenses: [Expense] = [],
        contributions: [DreamContribution] = []
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.categoryRawValue = categoryRawValue
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.expenses = expenses
        self.contributions = contributions
    }

    var category: GoalCategory {
        get {
            GoalCategory(rawValue: categoryRawValue) ?? .custom
        }
        set {
            categoryRawValue = newValue.rawValue
            emoji = newValue.emoji
        }
    }

    var targetDate: Date? {
        get { deadline }
        set { deadline = newValue }
    }

    func touch() {
        updatedAt = .now
    }
}

extension Goal: Equatable {
    static func == (lhs: Goal, rhs: Goal) -> Bool {
        lhs.id == rhs.id
    }
}

extension Goal {
    static let mockBali = Goal(
        name: "Bali trip",
        emoji: GoalCategory.travel.emoji,
        categoryRawValue: GoalCategory.travel.rawValue,
        targetAmount: 120_000,
        currentAmount: 25_000,
        deadline: Calendar.current.date(byAdding: .month, value: 8, to: .now)
    )

    static let mockGaming = Goal(
        name: "Gaming setup",
        emoji: GoalCategory.gaming.emoji,
        categoryRawValue: GoalCategory.gaming.rawValue,
        targetAmount: 85_000,
        currentAmount: 48_000,
        deadline: Calendar.current.date(byAdding: .month, value: 5, to: .now)
    )

    static let mockEmergency = Goal(
        name: "Emergency fund",
        emoji: GoalCategory.emergency.emoji,
        categoryRawValue: GoalCategory.emergency.rawValue,
        targetAmount: 300_000,
        currentAmount: 80_000,
        deadline: Calendar.current.date(byAdding: .month, value: 14, to: .now)
    )
}
