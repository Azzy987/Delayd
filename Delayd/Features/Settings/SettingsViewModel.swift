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
    var smartDelayRemindersEnabled = true
    var weeklyDreamRecapEnabled = true
    var tone: DelaydTone = .motivational
    var appTheme: AppTheme = .system
    var dailyReminderTime = DateComponents(hour: 20, minute: 0)
    var smartReminderTime = DateComponents(hour: 17, minute: 30)
    var weeklyRecapTime = DateComponents(hour: 18, minute: 0)

    /// (id → name) lookup for active goals so the Settings row can render the
    /// human label for the current `defaultGoalId` without an `@Query` in the
    /// view model.
    private(set) var goalNamesById: [UUID: String] = [:]

    private var modelContainer: ModelContainer?
    private let dailyDelaySummaryKey = "delayd.notifications.dailyDelaySummaryEnabled"
    private let smartDelayRemindersKey = "delayd.notifications.smartDelayRemindersEnabled"
    private let weeklyDreamRecapKey = "delayd.notifications.weeklyDreamRecapEnabled"
    private let dailyReminderHourKey = "delayd.notifications.dailyReminder.hour"
    private let dailyReminderMinuteKey = "delayd.notifications.dailyReminder.minute"
    private let smartReminderHourKey = "delayd.notifications.smartReminder.hour"
    private let smartReminderMinuteKey = "delayd.notifications.smartReminder.minute"
    private let weeklyRecapHourKey = "delayd.notifications.weeklyRecap.hour"
    private let weeklyRecapMinuteKey = "delayd.notifications.weeklyRecap.minute"

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

    var dailyReminderTimeText: String {
        Self.timeText(from: dailyReminderTime)
    }

    var smartReminderTimeText: String {
        Self.timeText(from: smartReminderTime)
    }

    var weeklyRecapTimeText: String {
        Self.timeText(from: weeklyRecapTime)
    }

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
        smartDelayRemindersEnabled = UserDefaults.standard.object(forKey: smartDelayRemindersKey) as? Bool ?? true
        weeklyDreamRecapEnabled = UserDefaults.standard.object(forKey: weeklyDreamRecapKey) as? Bool ?? true
        dailyReminderTime = Self.loadTimeComponents(
            hourKey: dailyReminderHourKey,
            minuteKey: dailyReminderMinuteKey,
            defaultHour: 20,
            defaultMinute: 0
        )
        smartReminderTime = Self.loadTimeComponents(
            hourKey: smartReminderHourKey,
            minuteKey: smartReminderMinuteKey,
            defaultHour: 17,
            defaultMinute: 30
        )
        weeklyRecapTime = Self.loadTimeComponents(
            hourKey: weeklyRecapHourKey,
            minuteKey: weeklyRecapMinuteKey,
            defaultHour: 18,
            defaultMinute: 0
        )
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

    func updateSmartDelayReminders(enabled: Bool) {
        smartDelayRemindersEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: smartDelayRemindersKey)
        if notificationsEnabled {
            scheduleDefaultNotifications()
        }
    }

    func updateWeeklyDreamRecap(enabled: Bool) {
        weeklyDreamRecapEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: weeklyDreamRecapKey)
        if notificationsEnabled {
            scheduleDefaultNotifications()
        }
    }

    func updateDailyReminderTime(_ components: DateComponents) {
        dailyReminderTime = Self.normalizedTime(components, defaultHour: 20, defaultMinute: 0)
        persistTime(
            dailyReminderTime,
            hourKey: dailyReminderHourKey,
            minuteKey: dailyReminderMinuteKey
        )
        if notificationsEnabled {
            scheduleDefaultNotifications()
        }
    }

    func updateSmartReminderTime(_ components: DateComponents) {
        smartReminderTime = Self.normalizedTime(components, defaultHour: 17, defaultMinute: 30)
        persistTime(
            smartReminderTime,
            hourKey: smartReminderHourKey,
            minuteKey: smartReminderMinuteKey
        )
        if notificationsEnabled {
            scheduleDefaultNotifications()
        }
    }

    func updateWeeklyRecapTime(_ components: DateComponents) {
        weeklyRecapTime = Self.normalizedTime(components, defaultHour: 18, defaultMinute: 0)
        persistTime(
            weeklyRecapTime,
            hourKey: weeklyRecapHourKey,
            minuteKey: weeklyRecapMinuteKey
        )
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
        dateComponents.hour = dailyReminderTime.hour
        dateComponents.minute = dailyReminderTime.minute

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

            let summaryDate = Self.summaryTimeComponents(from: dailyReminderTime)

            center.add(
                UNNotificationRequest(
                    identifier: "delayd.dailyDelaySummary",
                    content: summary,
                    trigger: UNCalendarNotificationTrigger(dateMatching: summaryDate, repeats: true)
                )
            )
        }

        guard ProEntitlementService.isUnlocked, let modelContainer else { return }

        Task {
            let (recapBody, smartBody) = await makeProNotificationBodies(modelContainer: modelContainer)

            if weeklyDreamRecapEnabled {
                let recap = UNMutableNotificationContent()
                recap.title = "Weekly dream recap"
                recap.body = recapBody
                recap.sound = .default

                var recapDate = DateComponents()
                recapDate.weekday = 1
                recapDate.hour = weeklyRecapTime.hour
                recapDate.minute = weeklyRecapTime.minute

                try? await center.add(
                    UNNotificationRequest(
                        identifier: "delayd.weeklyRecap",
                        content: recap,
                        trigger: UNCalendarNotificationTrigger(dateMatching: recapDate, repeats: true)
                    )
                )
            }

            if smartDelayRemindersEnabled {
                let smart = UNMutableNotificationContent()
                smart.title = "Smart delay reminder"
                smart.body = smartBody
                smart.sound = .default

                var smartDate = DateComponents()
                smartDate.hour = smartReminderTime.hour
                smartDate.minute = smartReminderTime.minute

                try? await center.add(
                    UNNotificationRequest(
                        identifier: "delayd.smartDelayReminder",
                        content: smart,
                        trigger: UNCalendarNotificationTrigger(dateMatching: smartDate, repeats: true)
                    )
                )
            }
        }
    }

    private func makeProNotificationBodies(modelContainer: ModelContainer) async -> (weekly: String, smart: String) {
        let expenseRepo = ExpenseRepository(modelContainer: modelContainer)
        let contributionRepo = DreamContributionRepository(modelContainer: modelContainer)

        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let prevWeekStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        let thisWeek = DateInterval(start: weekStart, end: now)
        let prevWeek = DateInterval(start: prevWeekStart, end: weekStart)

        async let thisWeekExpensesTask = expenseRepo.fetchAllSnapshots(in: thisWeek)
        async let prevWeekExpensesTask = expenseRepo.fetchAllSnapshots(in: prevWeek)
        async let thisWeekSavedTask = contributionRepo.fetchAllSnapshots(in: thisWeek)

        let thisWeekExpenses = await thisWeekExpensesTask
        let prevWeekExpenses = await prevWeekExpensesTask
        let thisWeekSaved = await thisWeekSavedTask

        let thisWeekSpend = thisWeekExpenses.reduce(0) { $0 + $1.amount }
        let prevWeekSpend = prevWeekExpenses.reduce(0) { $0 + $1.amount }
        let savedAmount = thisWeekSaved.reduce(0) { $0 + $1.amount }

        let smartBody: String
        if prevWeekSpend > 0, thisWeekSpend > prevWeekSpend * 1.12 {
            let pct = Int(((thisWeekSpend - prevWeekSpend) / prevWeekSpend * 100).rounded())
            smartBody = "You're spending \(pct)% more than last week. Log tonight to catch delay creep early."
        } else if thisWeekExpenses.count >= 8 {
            smartBody = "Frequent spends this week can quietly add delay days. Log now and protect your pace."
        } else {
            smartBody = "Quick check: one small spend today can still move your dream timeline. Log it while fresh."
        }

        let recapBody: String
        if thisWeekExpenses.isEmpty && thisWeekSaved.isEmpty {
            recapBody = "Quiet week. Keep the streak by protecting one small amount before Monday ends."
        } else {
            let spendText = CurrencyFormatter.format(thisWeekSpend, currencyCode: selectedCurrency)
            let savedText = CurrencyFormatter.format(savedAmount, currencyCode: selectedCurrency)
            recapBody = "This week: spent \(spendText), protected \(savedText). Review your biggest delay trigger before next week starts."
        }

        return (recapBody, smartBody)
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

    private func persistTime(_ components: DateComponents, hourKey: String, minuteKey: String) {
        UserDefaults.standard.set(components.hour ?? 0, forKey: hourKey)
        UserDefaults.standard.set(components.minute ?? 0, forKey: minuteKey)
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

    /// Rebuild pending local notifications from current data/state.
    /// Called after logging/protecting so smart reminder + weekly recap copy
    /// stays aligned with the latest week trend.
    static func refreshNotificationSchedulesIfNeeded(modelContainer: ModelContainer) async {
        let repository = SettingsRepository(modelContainer: modelContainer)
        let snapshot = await repository.fetchSnapshot()
        guard snapshot.notificationsEnabled else { return }

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let dailyDelaySummaryEnabled = UserDefaults.standard.bool(forKey: "delayd.notifications.dailyDelaySummaryEnabled")
        let smartDelayRemindersEnabled = UserDefaults.standard.object(forKey: "delayd.notifications.smartDelayRemindersEnabled") as? Bool ?? true
        let weeklyDreamRecapEnabled = UserDefaults.standard.object(forKey: "delayd.notifications.weeklyDreamRecapEnabled") as? Bool ?? true
        let dailyTime = loadTimeComponents(
            hourKey: "delayd.notifications.dailyReminder.hour",
            minuteKey: "delayd.notifications.dailyReminder.minute",
            defaultHour: 20,
            defaultMinute: 0
        )
        let smartTime = loadTimeComponents(
            hourKey: "delayd.notifications.smartReminder.hour",
            minuteKey: "delayd.notifications.smartReminder.minute",
            defaultHour: 17,
            defaultMinute: 30
        )
        let recapTime = loadTimeComponents(
            hourKey: "delayd.notifications.weeklyRecap.hour",
            minuteKey: "delayd.notifications.weeklyRecap.minute",
            defaultHour: 18,
            defaultMinute: 0
        )

        let content = UNMutableNotificationContent()
        content.title = "Delayd"
        content.body = ToneCopy.dailyNudge(tone: snapshot.tone)
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = dailyTime.hour
        dateComponents.minute = dailyTime.minute

        try? await center.add(
            UNNotificationRequest(
                identifier: "delayd.dailyNudge",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            )
        )

        if dailyDelaySummaryEnabled {
            let summary = UNMutableNotificationContent()
            summary.title = "Daily delay summary"
            summary.body = ToneCopy.dailyNudge(tone: snapshot.tone)
            summary.sound = .default

            let summaryDate = summaryTimeComponents(from: dailyTime)

            try? await center.add(
                UNNotificationRequest(
                    identifier: "delayd.dailyDelaySummary",
                    content: summary,
                    trigger: UNCalendarNotificationTrigger(dateMatching: summaryDate, repeats: true)
                )
            )
        }

        guard ProEntitlementService.isUnlocked else { return }
        let bodies = await makeProNotificationBodies(
            modelContainer: modelContainer,
            currencyCode: snapshot.defaultCurrency
        )

        if weeklyDreamRecapEnabled {
            let recap = UNMutableNotificationContent()
            recap.title = "Weekly dream recap"
            recap.body = bodies.weekly
            recap.sound = .default

            var recapDate = DateComponents()
            recapDate.weekday = 1
            recapDate.hour = recapTime.hour
            recapDate.minute = recapTime.minute

            try? await center.add(
                UNNotificationRequest(
                    identifier: "delayd.weeklyRecap",
                    content: recap,
                    trigger: UNCalendarNotificationTrigger(dateMatching: recapDate, repeats: true)
                )
            )
        }

        if smartDelayRemindersEnabled {
            let smart = UNMutableNotificationContent()
            smart.title = "Smart delay reminder"
            smart.body = bodies.smart
            smart.sound = .default

            var smartDate = DateComponents()
            smartDate.hour = smartTime.hour
            smartDate.minute = smartTime.minute

            try? await center.add(
                UNNotificationRequest(
                    identifier: "delayd.smartDelayReminder",
                    content: smart,
                    trigger: UNCalendarNotificationTrigger(dateMatching: smartDate, repeats: true)
                )
            )
        }
    }

    private static func makeProNotificationBodies(
        modelContainer: ModelContainer,
        currencyCode: String
    ) async -> (weekly: String, smart: String) {
        let expenseRepo = ExpenseRepository(modelContainer: modelContainer)
        let contributionRepo = DreamContributionRepository(modelContainer: modelContainer)

        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let prevWeekStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        let thisWeek = DateInterval(start: weekStart, end: now)
        let prevWeek = DateInterval(start: prevWeekStart, end: weekStart)

        async let thisWeekExpensesTask = expenseRepo.fetchAllSnapshots(in: thisWeek)
        async let prevWeekExpensesTask = expenseRepo.fetchAllSnapshots(in: prevWeek)
        async let thisWeekSavedTask = contributionRepo.fetchAllSnapshots(in: thisWeek)

        let thisWeekExpenses = await thisWeekExpensesTask
        let prevWeekExpenses = await prevWeekExpensesTask
        let thisWeekSaved = await thisWeekSavedTask

        let thisWeekSpend = thisWeekExpenses.reduce(0) { $0 + $1.amount }
        let prevWeekSpend = prevWeekExpenses.reduce(0) { $0 + $1.amount }
        let savedAmount = thisWeekSaved.reduce(0) { $0 + $1.amount }

        let smartBody: String
        if prevWeekSpend > 0, thisWeekSpend > prevWeekSpend * 1.12 {
            let pct = Int(((thisWeekSpend - prevWeekSpend) / prevWeekSpend * 100).rounded())
            smartBody = "You're spending \(pct)% more than last week. Log tonight to catch delay creep early."
        } else if thisWeekExpenses.count >= 8 {
            smartBody = "Frequent spends this week can quietly add delay days. Log now and protect your pace."
        } else {
            smartBody = "Quick check: one small spend today can still move your dream timeline. Log it while fresh."
        }

        let recapBody: String
        if thisWeekExpenses.isEmpty && thisWeekSaved.isEmpty {
            recapBody = "Quiet week. Keep the streak by protecting one small amount before Monday ends."
        } else {
            let spendText = CurrencyFormatter.format(thisWeekSpend, currencyCode: currencyCode)
            let savedText = CurrencyFormatter.format(savedAmount, currencyCode: currencyCode)
            recapBody = "This week: spent \(spendText), protected \(savedText). Review your biggest delay trigger before next week starts."
        }

        return (recapBody, smartBody)
    }

    private static func loadTimeComponents(
        hourKey: String,
        minuteKey: String,
        defaultHour: Int,
        defaultMinute: Int
    ) -> DateComponents {
        let hour = UserDefaults.standard.object(forKey: hourKey) as? Int ?? defaultHour
        let minute = UserDefaults.standard.object(forKey: minuteKey) as? Int ?? defaultMinute
        return normalizedTime(DateComponents(hour: hour, minute: minute), defaultHour: defaultHour, defaultMinute: defaultMinute)
    }

    private static func normalizedTime(_ components: DateComponents, defaultHour: Int, defaultMinute: Int) -> DateComponents {
        let hour = (components.hour ?? defaultHour).clamped(to: 0...23)
        let minute = (components.minute ?? defaultMinute).clamped(to: 0...59)
        return DateComponents(hour: hour, minute: minute)
    }

    private static func summaryTimeComponents(from daily: DateComponents) -> DateComponents {
        let hour = daily.hour ?? 20
        let minute = daily.minute ?? 0
        let dailyDate = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        let summaryDate = Calendar.current.date(byAdding: .hour, value: 1, to: dailyDate) ?? dailyDate
        let comps = Calendar.current.dateComponents([.hour, .minute], from: summaryDate)
        return DateComponents(hour: comps.hour ?? 21, minute: comps.minute ?? 0)
    }

    private static func timeText(from components: DateComponents) -> String {
        var date = DateComponents()
        date.hour = components.hour
        date.minute = components.minute
        guard let value = Calendar.current.date(from: date) else { return "8:00 PM" }
        return value.formatted(.dateTime.hour().minute())
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#Preview("Settings View Model") {
    Text(SettingsViewModel.mock().monthlySavingsText)
        .font(AppTypography.bodyMedium)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
