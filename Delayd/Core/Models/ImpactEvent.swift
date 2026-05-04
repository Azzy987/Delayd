import Foundation
import SwiftData

@Model
final class ImpactEvent {
    @Attribute(.unique) var id: UUID
    var expenseId: UUID
    var goalId: UUID
    var delayDays: Int
    var previousProgress: Double
    var newProgress: Double
    var calculatedAt: Date

    init(
        id: UUID = UUID(),
        expenseId: UUID,
        goalId: UUID,
        delayDays: Int,
        previousProgress: Double,
        newProgress: Double,
        calculatedAt: Date = .now
    ) {
        self.id = id
        self.expenseId = expenseId
        self.goalId = goalId
        self.delayDays = delayDays
        self.previousProgress = previousProgress
        self.newProgress = newProgress
        self.calculatedAt = calculatedAt
    }
}
