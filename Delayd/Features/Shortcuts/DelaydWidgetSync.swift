import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Writes a minimal snapshot of the user's default goal to shared
/// UserDefaults so the widget extension can render without touching SwiftData
/// (widgets get tight memory budgets and SwiftData init is expensive).
///
/// Call `refresh(...)` after any goal/expense change. It's cheap (writes a
/// small JSON blob), and it asks WidgetKit to reload timelines so the widget
/// updates immediately instead of waiting for the next scheduled refresh.
///
/// **Requires App Group `group.com.delayd.shared` enabled on BOTH the main
/// app target and the widget target** — see `DelaydWidget/SETUP.md`. Until
/// the App Group is configured this fails silently (by design — the app
/// still works fine without the widget).
enum DelaydWidgetSync {
    private static let appGroupID = "group.com.delayd.shared"
    private static let entryKey = "widget.entry"
    private static let trialStartDateKey = "widget.trial.startDate"
    private static let proUnlockedKey = "widget.pro.unlocked"
    private static let trialDurationDays = 7

    static func bootstrapTrialIfNeeded() {
        let now = Date()
        if UserDefaults.standard.object(forKey: trialStartDateKey) == nil {
            UserDefaults.standard.set(now, forKey: trialStartDateKey)
        }

        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            return
        }
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if defaults.object(forKey: trialStartDateKey) == nil {
            defaults.set(now, forKey: trialStartDateKey)
        }
    }

    static func syncProState(isUnlocked: Bool) {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            return
        }
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(isUnlocked, forKey: proUnlockedKey)
        bootstrapTrialIfNeeded()
    }

    static func widgetTrialDaysLeft(now: Date = .now) -> Int {
        let startDate = (UserDefaults.standard.object(forKey: trialStartDateKey) as? Date) ?? now
        let elapsedDays = max(0, Calendar.current.dateComponents([.day], from: startDate, to: now).day ?? 0)
        return max(0, trialDurationDays - elapsedDays)
    }

    static func refresh(
        goalName: String,
        goalEmoji: String,
        goalIllustrationAssetName: String,
        progress: Double,
        daysDelayed: Int,
        savedAmount: Double,
        currencySymbol: String = "₹"
    ) {
        bootstrapTrialIfNeeded()
        syncProState(isUnlocked: ProEntitlementService.isUnlocked)

        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            return
        }
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        let payload = WidgetEntryPayload(
            goalName: goalName,
            goalEmoji: goalEmoji,
            goalIllustrationAssetName: goalIllustrationAssetName,
            progress: progress,
            daysDelayed: daysDelayed,
            savedAmount: savedAmount,
            currencySymbol: currencySymbol,
            writtenAt: .now
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: entryKey)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Matches `DelaydWidgetEntryDTO` in the widget target. Kept as a private
    /// local type so the main app doesn't need to import the widget's types
    /// (the widget lives in a separate module).
    private struct WidgetEntryPayload: Codable {
        let goalName: String
        let goalEmoji: String
        let goalIllustrationAssetName: String
        let progress: Double
        let daysDelayed: Int
        let savedAmount: Double
        let currencySymbol: String
        let writtenAt: Date
    }
}
