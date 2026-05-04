import Foundation
import SwiftUI

struct GoalSnapshot: Identifiable, Equatable {
    let id: UUID
    var name: String
    var emoji: String
    var category: GoalCategory
    var targetAmount: Double
    var currentAmount: Double
    var targetDate: Date?

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        category: GoalCategory,
        targetAmount: Double,
        currentAmount: Double,
        targetDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.category = category
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
    }

    nonisolated init(goal: Goal) {
        self.init(
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

extension GoalSnapshot {
    static let mockBali = GoalSnapshot(
        name: "Bali trip",
        emoji: GoalCategory.travel.emoji,
        category: .travel,
        targetAmount: 120_000,
        currentAmount: 25_000,
        targetDate: Calendar.current.date(byAdding: .month, value: 8, to: .now)
    )

    static let mockGaming = GoalSnapshot(
        name: "Gaming setup",
        emoji: GoalCategory.gaming.emoji,
        category: .gaming,
        targetAmount: 85_000,
        currentAmount: 48_000,
        targetDate: Calendar.current.date(byAdding: .month, value: 5, to: .now)
    )

    static let mockEmergency = GoalSnapshot(
        name: "Emergency fund",
        emoji: GoalCategory.emergency.emoji,
        category: .emergency,
        targetAmount: 300_000,
        currentAmount: 80_000,
        targetDate: Calendar.current.date(byAdding: .month, value: 14, to: .now)
    )
}

#Preview("Goal Snapshot") {
    Text(GoalSnapshot.mockBali.name)
        .font(AppTypography.bodyMedium)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
