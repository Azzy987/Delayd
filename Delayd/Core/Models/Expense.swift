import Foundation
import SwiftData

@Model
final class Expense {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var merchant: String?
    var tag: String?
    var note: String?
    var occurredAt: Date
    var createdAt: Date
    var updatedAt: Date

    var linkedGoal: Goal?

    init(
        id: UUID = UUID(),
        amount: Double,
        merchant: String? = nil,
        tag: String? = nil,
        note: String? = nil,
        occurredAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        linkedGoal: Goal? = nil
    ) {
        self.id = id
        self.amount = amount
        self.merchant = merchant
        self.tag = tag
        self.note = note
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedGoal = linkedGoal
    }

    func touch() {
        updatedAt = .now
    }
}
