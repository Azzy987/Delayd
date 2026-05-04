import Foundation
import SwiftUI

struct UserSettingsSnapshot: Equatable {
    let id: UUID
    var defaultCurrency: String
    var monthlySavingsTarget: Double
    var hapticsEnabled: Bool
    var notificationsEnabled: Bool
    var onboardingCompleted: Bool
    var defaultGoalId: UUID?
    var tone: DelaydTone
    var appTheme: AppTheme

    nonisolated init(
        id: UUID,
        defaultCurrency: String,
        monthlySavingsTarget: Double,
        hapticsEnabled: Bool,
        notificationsEnabled: Bool,
        onboardingCompleted: Bool,
        defaultGoalId: UUID?,
        tone: DelaydTone = .motivational,
        appTheme: AppTheme = .system
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
    }
}

#Preview("User Settings Snapshot") {
    Text("INR • ₹10,000 monthly target")
        .font(AppTypography.bodyMedium)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
