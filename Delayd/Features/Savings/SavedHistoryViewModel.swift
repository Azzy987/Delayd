import SwiftUI
import Observation
import SwiftData

/// Backs `SavedHistorySheet`. Loads every Protect-Dream contribution from
/// SwiftData, joins each one to its goal name (via the goal repository so
/// we don't keep live `Goal` model instances around — the SwiftData
/// container can be wiped/reseeded from Settings), and groups results by
/// day for display.
///
/// Filtering by goal happens in-memory via `selectGoal(_:)` because the
/// dataset is small (one row per Protect-Dream tap) and a re-query would
/// add latency without changing what the user sees.
@Observable
@MainActor
final class SavedHistoryViewModel {
    var sections: [SavedDaySection]
    /// `nil` selectedGoalId means "All dreams". Otherwise filter by this Goal.id.
    var selectedGoalId: UUID?
    var availableGoals: [GoalFilterOption]

    /// Cached raw snapshots so filter changes don't need a DB round-trip.
    private var allContributions: [DreamContributionSnapshot] = []
    private var goalLookup: [UUID: GoalFilterOption] = [:]
    private(set) var currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode

    init(
        sections: [SavedDaySection] = [],
        selectedGoalId: UUID? = nil,
        availableGoals: [GoalFilterOption] = []
    ) {
        self.sections = sections
        self.selectedGoalId = selectedGoalId
        self.availableGoals = availableGoals
    }

    var isEmpty: Bool {
        sections.isEmpty
    }

    /// Title for the chip on the Saved sheet's filter bar.
    var selectedGoalTitle: String {
        guard let selectedGoalId,
              let match = availableGoals.first(where: { $0.id == selectedGoalId }) else {
            return "All Dreams"
        }
        return match.name
    }

    /// "All time saved" / "Saved for {goal}" depending on the active filter.
    var summaryTitle: String {
        guard let selectedGoalId,
              let match = availableGoals.first(where: { $0.id == selectedGoalId }) else {
            return "All-time saved"
        }
        return "Saved for \(match.name)"
    }

    var summaryAmountText: String {
        let total = filteredContributions.reduce(0) { $0 + $1.amount }
        return CurrencyFormatter.format(total, currencyCode: currencyCode)
    }

    var totalEntryCount: Int {
        filteredContributions.count
    }

    func selectGoal(_ goalId: UUID?) {
        selectedGoalId = goalId
        rebuildSections()
    }

    func load(modelContainer: ModelContainer) async {
        let contributionRepository = DreamContributionRepository(modelContainer: modelContainer)
        let goalRepository = GoalRepository(modelContainer: modelContainer)
        let settingsRepository = SettingsRepository(modelContainer: modelContainer)

        async let contributionsTask = contributionRepository.fetchAllSnapshots(in: nil)
        async let goalsTask = goalRepository.fetchActive()
        async let settingsTask = settingsRepository.fetchSnapshot()

        allContributions = await contributionsTask
        let goals = await goalsTask
        let settings = await settingsTask

        availableGoals = goals.map { GoalFilterOption(id: $0.id, name: $0.name, emoji: $0.emoji) }
        goalLookup = Dictionary(uniqueKeysWithValues: availableGoals.map { ($0.id, $0) })
        currencyCode = settings.defaultCurrency

        rebuildSections()
    }

    func delete(id: UUID, modelContainer: ModelContainer) async {
        let repository = DreamContributionRepository(modelContainer: modelContainer)
        await repository.delete(id: id)
        allContributions.removeAll { $0.id == id }
        rebuildSections()
    }

    // MARK: - Section building

    private var filteredContributions: [DreamContributionSnapshot] {
        guard let selectedGoalId else { return allContributions }
        return allContributions.filter { $0.goalId == selectedGoalId }
    }

    private func rebuildSections() {
        let grouped = Dictionary(grouping: filteredContributions) { entry in
            Calendar.current.startOfDay(for: entry.occurredAt)
        }

        sections = grouped
            .sorted { $0.key > $1.key }
            .map { day, contributions in
                let entries = contributions
                    .sorted { $0.occurredAt > $1.occurredAt }
                    .map { snapshot in
                        SavedHistoryEntry(
                            id: snapshot.id,
                            goalName: goalName(for: snapshot.goalId),
                            locationSymbol: snapshot.location.symbolName,
                            subtitle: subtitle(for: snapshot),
                            amountText: CurrencyFormatter.format(snapshot.amount, currencyCode: currencyCode)
                        )
                    }
                let total = contributions.reduce(0) { $0 + $1.amount }
                return SavedDaySection(
                    title: Self.title(for: day),
                    totalText: "+\(CurrencyFormatter.format(total, currencyCode: currencyCode))",
                    entries: entries
                )
            }
    }

    private func subtitle(for snapshot: DreamContributionSnapshot) -> String {
        let timeText = snapshot.occurredAt.formatted(date: .omitted, time: .shortened)
        return "\(snapshot.location.title) • \(timeText)"
    }

    private func goalName(for goalId: UUID?) -> String {
        guard let goalId, let match = goalLookup[goalId] else { return "Dream" }
        return "\(match.emoji)  \(match.name.delaydGoalTitleCased)"
    }

    private static func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Display models

/// View-friendly day grouping shown by `SavedHistorySheet`.
struct SavedDaySection: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let totalText: String
    let entries: [SavedHistoryEntry]
}

/// One Protect-Dream entry as displayed in the Saved sheet.
/// Decoupled from `DreamContributionSnapshot` so the view doesn't need to
/// know the SwiftData snapshot shape and can be previewed cleanly.
struct SavedHistoryEntry: Identifiable, Equatable {
    let id: UUID
    let goalName: String
    let locationSymbol: String
    let subtitle: String
    let amountText: String
}

// MARK: - Previews

extension SavedHistoryViewModel {
    static func mockEmpty() -> SavedHistoryViewModel {
        SavedHistoryViewModel(sections: [])
    }

    static func mockPopulated() -> SavedHistoryViewModel {
        let today = SavedDaySection(
            title: "Today",
            totalText: "+₹3,500",
            entries: [
                SavedHistoryEntry(
                    id: UUID(),
                    goalName: "🏖️  Bali Trip",
                    locationSymbol: "shippingbox.fill",
                    subtitle: "Piggy bank • 9:42 AM",
                    amountText: "₹2,000"
                ),
                SavedHistoryEntry(
                    id: UUID(),
                    goalName: "🎮  Gaming Setup",
                    locationSymbol: "building.columns.fill",
                    subtitle: "Bank • 7:18 AM",
                    amountText: "₹1,500"
                )
            ]
        )

        let yesterday = SavedDaySection(
            title: "Yesterday",
            totalText: "+₹4,000",
            entries: [
                SavedHistoryEntry(
                    id: UUID(),
                    goalName: "🏖️  Bali Trip",
                    locationSymbol: "banknote.fill",
                    subtitle: "Cash • 6:05 PM",
                    amountText: "₹4,000"
                )
            ]
        )

        return SavedHistoryViewModel(
            sections: [today, yesterday],
            availableGoals: [
                GoalFilterOption(id: UUID(), name: "Bali Trip", emoji: "🏖️"),
                GoalFilterOption(id: UUID(), name: "Gaming Setup", emoji: "🎮")
            ]
        )
    }
}
