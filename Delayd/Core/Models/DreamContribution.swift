import Foundation
import SwiftData
import SwiftUI

enum DreamSavingsLocation: String, CaseIterable, Identifiable, Codable, Sendable {
    case piggyBank
    case bank
    case cash
    case locker
    case family
    case friend
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .piggyBank: "Piggy bank"
        case .bank: "Bank"
        case .cash: "Cash"
        case .locker: "Locker"
        case .family: "With family"
        case .friend: "With friend"
        case .other: "Somewhere safe"
        }
    }

    var symbolName: String {
        switch self {
        case .piggyBank: "shippingbox.fill"
        case .bank: "building.columns.fill"
        case .cash: "banknote.fill"
        case .locker: "lock.fill"
        case .family: "person.2.fill"
        case .friend: "person.fill"
        case .other: "sparkle.magnifyingglass"
        }
    }
}

@Model
final class DreamContribution {
    @Attribute(.unique) var id: UUID
    var amount: Double
    var locationRawValue: String
    var note: String?
    var occurredAt: Date
    var createdAt: Date
    var updatedAt: Date

    var linkedGoal: Goal?

    init(
        id: UUID = UUID(),
        amount: Double,
        location: DreamSavingsLocation,
        note: String? = nil,
        occurredAt: Date = .now,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        linkedGoal: Goal? = nil
    ) {
        self.id = id
        self.amount = amount
        self.locationRawValue = location.rawValue
        self.note = note
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedGoal = linkedGoal
    }

    var location: DreamSavingsLocation {
        get { DreamSavingsLocation(rawValue: locationRawValue) ?? .other }
        set { locationRawValue = newValue.rawValue }
    }

    func touch() {
        updatedAt = .now
    }
}
