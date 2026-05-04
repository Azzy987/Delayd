import SwiftUI
import Observation
import SwiftData
import UserNotifications

@Observable
final class SettingsViewModel {
    var selectedCurrency = CurrencyFormatter.localeDefaultCurrencyCode
    var monthlySavingsTarget = 10_000.0
    /// Stable identifier for the user's default goal. Display name is
    /// resolved from the live SwiftData rows in `defaultGoalName` so renaming
    /// a goal updates the Settings row automatically.
    var defaultGoalId: UUID?
    var notificationsEnabled = false
    var hapticsEnabled = true
    var dailyDelaySummaryEnabled = false
    var tone: DelaydTone = .motivational
    var appTheme: AppTheme = .system

    /// (id → name) lookup for active goals so the Settings row can render the
    /// human label for the current `defaultGoalId` without an `@Query` in the
    /// view model.
    private(set) var goalNamesById: [UUID: String] = [:]

    private var modelContainer: ModelContainer?
    private let dailyDelaySummaryKey = "delayd.notifications.dailyDelaySummaryEnabled"

    var monthlySavingsText: String {
        "\(CurrencyFormatter.format(monthlySavingsTarget, currencyCode: selectedCurrency))/month"
    }

    /// Resolved display name for the currently selected default goal. Falls
    /// back to a friendly placeholder when nothing is selected or the cache
    /// hasn't loaded yet.
    var defaultGoalName: String {
        if let id = defaultGoalId, let name = goalNamesById[id] {
            return name.delaydGoalTitleCased
        }
        return "Not set"
    }

    var databaseStatsText: String {
        databaseStats
    }
    private var databaseStats = "Local only"

    func load(modelContainer: ModelContainer) async {
        self.modelContainer = modelContainer
        let repository = SettingsRepository(modelContainer: modelContainer)
        let snapshot = await repository.fetchSnapshot()
        selectedCurrency = snapshot.defaultCurrency
        monthlySavingsTarget = snapshot.monthlySavingsTarget
        hapticsEnabled = snapshot.hapticsEnabled
        tone = snapshot.tone
        appTheme = snapshot.appTheme
        defaultGoalId = snapshot.defaultGoalId
        dailyDelaySummaryEnabled = UserDefaults.standard.bool(forKey: dailyDelaySummaryKey)
        databaseStats = "Local only"

        // Populate the goal-name cache so the Settings row can render the
        // selected default goal's display name. If the persisted
        // `defaultGoalId` no longer exists (goal was deleted), clear it.
        let goalRepo = GoalRepository(modelContainer: modelContainer)
        let snapshots = await goalRepo.fetchActiveSnapshots()
        var map: [UUID: String] = [:]
        for s in snapshots { map[s.id] = s.name }
        goalNamesById = map
        if let id = defaultGoalId, map[id] == nil {
            defaultGoalId = nil
            persistDefaultGoalId(nil)
        }

        // Reconcile the notifications toggle with the real iOS permission
        // status so if the user revoked access in iOS Settings the toggle
        // reflects that on the next open instead of showing an incorrect "on".
        let unSettings = await UNUserNotificationCenter.current().notificationSettings()
        let systemGranted = unSettings.authorizationStatus == .authorized
            || unSettings.authorizationStatus == .provisional
        let persisted = snapshot.notificationsEnabled
        notificationsEnabled = persisted && systemGranted
        if persisted && !systemGranted {
            // Fix the drift silently — no toast needed.
            persistNotifications(false)
        }
    }

    /// Persist currency selection immediately to SwiftData.
    func updateCurrency(_ newCurrency: String) {
        selectedCurrency = newCurrency
        guard let modelContainer else { return }
        Task {
            let repository = SettingsRepository(modelContainer: modelContainer)
            await repository.update { settings in
                settings.defaultCurrency = newCurrency
            }
        }
    }

    /// Persist theme the moment the user picks it, writing to both SwiftData
    /// and UserDefaults so DelaydApp can read the choice synchronously on next
    /// launch (before SwiftData is ready).
    func updateTheme(_ newTheme: AppTheme) {
        appTheme = newTheme
        UserDefaults.standard.set(newTheme.rawValue, forKey: AppTheme.defaultsKey)
        NotificationCenter.default.post(name: .delaydThemeChanged, object: nil)
        guard let modelContainer else { return }
        Task {
            let repository = SettingsRepository(modelContainer: modelContainer)
            await repository.update { settings in
                settings.appTheme = newTheme.rawValue
            }
        }
    }

    /// Persist tone the moment the user picks a new one so other surfaces that
    /// re-read settings (Home insight, notifications) immediately match.
    func updateTone(_ newTone: DelaydTone) {
        tone = newTone
        guard let modelContainer else { return }
        Task {
            let repository = SettingsRepository(modelContainer: modelContainer)
            await repository.update { settings in
                settings.tone = newTone.rawValue
            }
        }
    }

    /// Called when the notifications toggle changes.
    /// Requests `UNUserNotificationCenter` authorization when enabling;
    /// reverts the toggle + persists if the user denies the system prompt.
    @MainActor
    func updateNotifications(enabled: Bool) async {
        guard enabled else {
            // User turned notifications off — persist immediately.
            notificationsEnabled = false
            persistNotifications(false)
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }

        // Check current status first — avoid redundant system prompt.
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            // Already granted — just update state and persist.
            notificationsEnabled = true
            persistNotifications(true)
            scheduleDefaultNotifications()

        case .notDetermined:
            // First time — show the system permission prompt.
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            notificationsEnabled = granted
            persistNotifications(granted)
            if granted { scheduleDefaultNotifications() }

        case .denied:
            // User has permanently denied — revert the toggle and prompt
            // them to open Settings instead.
            notificationsEnabled = false
            persistNotifications(false)

        @unknown default:
            notificationsEnabled = false
            persistNotifications(false)
        }
    }

    /// Persist the monthly savings target to SwiftData. Without this the
    /// MonthlySavingsTargetSheet wrote only to memory and reverted after
    /// relaunch.
    func updateMonthlySavingsTarget(_ amount: Double) {
        monthlySavingsTarget = amount
        guard let modelContainer else { return }
        Task {
            let repository = SettingsRepository(modelContainer: modelContainer)
            await repository.update { settings in
                settings.monthlySavingsTarget = amount
            }
        }
    }

    /// Persist the default goal as a `UUID` (the stored field) instead of a
    /// display string. Updating this also flows through `defaultGoalName` via
    /// the cached `goalNamesById` map so the row label refreshes immediately.
    func updateDefaultGoal(id: UUID?) {
        defaultGoalId = id
        persistDefaultGoalId(id)
    }

    private func persistDefaultGoalId(_ id: UUID?) {
        guard let modelContainer else { return }
        Task {
            let repository = SettingsRepository(modelContainer: modelContainer)
            await repository.update { settings in
                settings.defaultGoalId = id
            }
        }
    }

    /// Persist the haptics toggle and schedule/cancel notifications to match.
    func updateHaptics(enabled: Bool) {
        hapticsEnabled = enabled
        guard let modelContainer else { return }
        Task {
            let repository = SettingsRepository(modelContainer: modelContainer)
            await repository.update { settings in
                settings.hapticsEnabled = enabled
            }
        }
    }

    func updateDailyDelaySummary(enabled: Bool) {
        dailyDelaySummaryEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: dailyDelaySummaryKey)
        if notificationsEnabled {
            scheduleDefaultNotifications()
        }
    }

    // MARK: - Notification scheduling

    /// Schedules a daily nudge notification at 20:00 (8 pm) to remind the
    /// user to log any expenses from the day. Uses `ToneCopy.dailyNudge` so
    /// the body copy matches the user's chosen tone.
    private func scheduleDefaultNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = "Delayd"
        content.body = ToneCopy.dailyNudge(tone: tone)
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: "delayd.dailyNudge",
            content: content,
            trigger: trigger
        )

        center.add(request)

        if dailyDelaySummaryEnabled {
            let summary = UNMutableNotificationContent()
            summary.title = "Daily delay summary"
            summary.body = ToneCopy.dailyNudge(tone: tone)
            summary.sound = .default

            var summaryDate = DateComponents()
            summaryDate.hour = 21
            summaryDate.minute = 0

            center.add(
                UNNotificationRequest(
                    identifier: "delayd.dailyDelaySummary",
                    content: summary,
                    trigger: UNCalendarNotificationTrigger(dateMatching: summaryDate, repeats: true)
                )
            )
        }

        guard ProEntitlementService.isUnlocked else { return }

        let recap = UNMutableNotificationContent()
        recap.title = "Weekly dream recap"
        recap.body = "Review what protected your goal, what delayed it, and the one spend to watch next week."
        recap.sound = .default

        var recapDate = DateComponents()
        recapDate.weekday = 1
        recapDate.hour = 18
        recapDate.minute = 0

        center.add(
            UNNotificationRequest(
                identifier: "delayd.weeklyRecap",
                content: recap,
                trigger: UNCalendarNotificationTrigger(dateMatching: recapDate, repeats: true)
            )
        )

        let smart = UNMutableNotificationContent()
        smart.title = "Small spend check"
        smart.body = "Tiny spends compound into delay days. Log today's small slips before they disappear from memory."
        smart.sound = .default

        var smartDate = DateComponents()
        smartDate.hour = 17
        smartDate.minute = 30

        center.add(
            UNNotificationRequest(
                identifier: "delayd.smartDelayReminder",
                content: smart,
                trigger: UNCalendarNotificationTrigger(dateMatching: smartDate, repeats: true)
            )
        )
    }

    private func persistNotifications(_ enabled: Bool) {
        guard let modelContainer else { return }
        Task {
            let repository = SettingsRepository(modelContainer: modelContainer)
            await repository.update { settings in
                settings.notificationsEnabled = enabled
            }
        }
    }

    func refreshStats(modelContext: ModelContext) {
        databaseStats = SeedDataService.stats(modelContext: modelContext)
    }

    func wipeAllData(modelContext: ModelContext) {
        SeedDataService.wipe(modelContext: modelContext)
        refreshStats(modelContext: modelContext)
    }

    func reseedDemoData(modelContext: ModelContext) {
        SeedDataService.reseed(modelContext: modelContext)
        refreshStats(modelContext: modelContext)
    }

}

extension SettingsViewModel {
    static func mock() -> SettingsViewModel {
        SettingsViewModel()
    }
}

#Preview("Settings View Model") {
    Text(SettingsViewModel.mock().monthlySavingsText)
        .font(AppTypography.bodyMedium)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
