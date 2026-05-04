import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var defaultCurrency: String
    var monthlySavingsTarget: Double
    var hapticsEnabled: Bool
    var notificationsEnabled: Bool
    var onboardingCompleted: Bool
    var defaultGoalId: UUID?
    /// Emotional tone for all user-facing copy (nudges, insights, reveals).
    /// Stored as rawValue so the SwiftData migration stays trivial; decoded
    /// into `DelaydTone` at snapshot time.
    var tone: String
    /// User's preferred colour-scheme override. Stored as rawValue of `AppTheme`.
    var appTheme: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        defaultCurrency: String = CurrencyFormatter.localeDefaultCurrencyCode,
        monthlySavingsTarget: Double = 10_000,
        hapticsEnabled: Bool = true,
        notificationsEnabled: Bool = false,
        onboardingCompleted: Bool = false,
        defaultGoalId: UUID? = nil,
        tone: String = DelaydTone.motivational.rawValue,
        appTheme: String = AppTheme.system.rawValue,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.defaultCurrency = defaultCurrency
        self.monthlySavingsTarget = monthlySavingsTarget
        self.hapticsEnabled = hapticsEnabled
        self.notificationsEnabled = notificationsEnabled
        self.onboardingCompleted = onboardingCompleted
        self.defaultGoalId = defaultGoalId
        self.tone = tone
        self.appTheme = appTheme
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func touch() {
        updatedAt = .now
    }
}
