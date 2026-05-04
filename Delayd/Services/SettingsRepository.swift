import Foundation
import SwiftData

@ModelActor
actor SettingsRepository {
    func fetch() async -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        if let settings = try? modelContext.fetch(descriptor).first {
            return settings
        }

        let settings = UserSettings()
        modelContext.insert(settings)
        save()
        return settings
    }

    func fetchSnapshot() async -> UserSettingsSnapshot {
        let settings = await fetch()
        return UserSettingsSnapshot(
            id: settings.id,
            defaultCurrency: settings.defaultCurrency,
            monthlySavingsTarget: settings.monthlySavingsTarget,
            hapticsEnabled: settings.hapticsEnabled,
            notificationsEnabled: settings.notificationsEnabled,
            onboardingCompleted: settings.onboardingCompleted,
            defaultGoalId: settings.defaultGoalId,
            tone: DelaydTone(rawValue: settings.tone) ?? .motivational,
            appTheme: AppTheme(rawValue: settings.appTheme) ?? .system
        )
    }

    func update(_ block: (UserSettings) -> Void) async {
        let settings = await fetch()
        block(settings)
        settings.touch()
        save()
    }

    private func save() {
        try? modelContext.save()
    }
}
