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

    /// Cached ledger rows (real contribution entries + synthetic starting
    /// balance rows from onboarding) so filter changes don't need a DB
    /// round-trip.
    private var allEntries: [SavedLedgerEntry] = []
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
        let total = filteredEntries.reduce(0) { $0 + $1.amount }
        return CurrencyFormatter.format(total, currencyCode: currencyCode)
    }

    var totalEntryCount: Int {
        filteredEntries.count
    }

    var startingEntries: [SavedHistoryEntry] {
        filteredEntries
            .filter { !$0.isDeletable }
            .sorted { $0.occurredAt > $1.occurredAt }
            .map { entry in
                SavedHistoryEntry(
                    id: entry.id,
                    goalName: goalName(for: entry.goalId),
                    goalCategory: goalCategory(for: entry.goalId),
                    locationTitle: entry.location.title,
                    locationSymbol: entry.location.symbolName,
                    occurredAt: entry.occurredAt,
                    subtitle: subtitle(for: entry),
                    amountText: CurrencyFormatter.format(entry.amount, currencyCode: currencyCode),
                    isDeletable: false,
                    isStartingBalance: true
                )
            }
    }

    var startingTotalText: String {
        let total = filteredEntries
            .filter { !$0.isDeletable }
            .reduce(0) { $0 + $1.amount }
        return CurrencyFormatter.format(total, currencyCode: currencyCode)
    }

    var transactionSections: [SavedDaySection] {
        sections.filter { section in
            section.entries.contains(where: \.isDeletable)
        }
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

        let contributionSnapshots = await contributionsTask
        let goals = await goalsTask
        let settings = await settingsTask

        availableGoals = goals.map { GoalFilterOption(id: $0.id, name: $0.name, emoji: $0.emoji, category: $0.category) }
        goalLookup = Dictionary(uniqueKeysWithValues: availableGoals.map { ($0.id, $0) })
        currencyCode = settings.defaultCurrency
        allEntries = buildLedgerEntries(contributions: contributionSnapshots, goals: goals)

        rebuildSections()
    }

    func delete(id: UUID, modelContainer: ModelContainer) async {
        guard let entry = allEntries.first(where: { $0.id == id }), entry.isDeletable else { return }
        let repository = DreamContributionRepository(modelContainer: modelContainer)
        await repository.delete(id: id)
        allEntries.removeAll { $0.id == id }
        rebuildSections()
    }

    // MARK: - Section building

    private var filteredEntries: [SavedLedgerEntry] {
        guard let selectedGoalId else { return allEntries }
        return allEntries.filter { $0.goalId == selectedGoalId }
    }

    private func rebuildSections() {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            Calendar.current.startOfDay(for: entry.occurredAt)
        }

        sections = grouped
            .sorted { $0.key > $1.key }
            .map { day, contributions in
                let entries = contributions
                    .sorted { $0.occurredAt > $1.occurredAt }
                    .map { entry in
                        SavedHistoryEntry(
                            id: entry.id,
                            goalName: goalName(for: entry.goalId),
                            goalCategory: goalCategory(for: entry.goalId),
                            locationTitle: entry.location.title,
                            locationSymbol: entry.location.symbolName,
                            occurredAt: entry.occurredAt,
                            subtitle: subtitle(for: entry),
                            amountText: CurrencyFormatter.format(entry.amount, currencyCode: currencyCode),
                            isDeletable: entry.isDeletable,
                            isStartingBalance: !entry.isDeletable
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

    private func subtitle(for entry: SavedLedgerEntry) -> String {
        let timeText = entry.occurredAt.formatted(date: .omitted, time: .shortened)
        if entry.isDeletable {
            return "\(entry.location.title) • \(timeText)"
        }
        return "Starting balance • \(timeText)"
    }

    private func goalName(for goalId: UUID?) -> String {
        guard let goalId, let match = goalLookup[goalId] else { return "Dream" }
        return match.name.delaydGoalTitleCased
    }

    private func goalCategory(for goalId: UUID?) -> GoalCategory {
        guard let goalId, let match = goalLookup[goalId] else { return .custom }
        return match.category
    }

    private static func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    private func buildLedgerEntries(contributions: [DreamContributionSnapshot], goals: [Goal]) -> [SavedLedgerEntry] {
        // Backward compatibility: older installs may have onboarding
        // contributions without the explicit "starting protected amount" note.
        // Recover those by matching the nearest goal-linked contribution around
        // goal creation time when no explicit starting row exists for that goal.
        var startingContributionIds = Set(
            contributions
                .filter { contribution in
                    (contribution.note ?? "")
                        .localizedCaseInsensitiveContains("starting protected amount")
                }
                .map(\.id)
        )
        let hasExplicitStartingByGoal = Dictionary(grouping: contributions, by: \.goalId)
            .mapValues { snapshots in
                snapshots.contains { snapshot in
                    (snapshot.note ?? "")
                        .localizedCaseInsensitiveContains("starting protected amount")
                }
            }

        for goal in goals {
            if hasExplicitStartingByGoal[goal.id] == true {
                continue
            }

            let candidates = contributions.filter { snapshot in
                guard snapshot.goalId == goal.id else { return false }
                return (snapshot.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            guard !candidates.isEmpty else { continue }

            let fallbackWindow: TimeInterval = 5 * 60
            if let nearest = candidates.min(by: { lhs, rhs in
                abs(lhs.occurredAt.timeIntervalSince(goal.createdAt)) < abs(rhs.occurredAt.timeIntervalSince(goal.createdAt))
            }),
                abs(nearest.occurredAt.timeIntervalSince(goal.createdAt)) <= fallbackWindow {
                startingContributionIds.insert(nearest.id)
            }
        }

        var rows = contributions.map {
            SavedLedgerEntry(
                id: $0.id,
                goalId: $0.goalId,
                amount: $0.amount,
                location: $0.location,
                occurredAt: $0.occurredAt,
                isDeletable: !startingContributionIds.contains($0.id)
            )
        }

        let contributionTotalsByGoal = Dictionary(grouping: contributions, by: \.goalId)
            .mapValues { snapshots in
                snapshots.reduce(0) { $0 + $1.amount }
            }

        for goal in goals {
            let contributed = contributionTotalsByGoal[goal.id] ?? 0
            let startingBalance = max(goal.currentAmount - contributed, 0)
            guard startingBalance > 0 else { continue }
            rows.append(
                SavedLedgerEntry(
                    id: goal.id,
                    goalId: goal.id,
                    amount: startingBalance,
                    location: .piggyBank,
                    occurredAt: goal.createdAt,
                    isDeletable: false
                )
            )
        }

        return rows.sorted { $0.occurredAt > $1.occurredAt }
    }
}

private struct SavedLedgerEntry {
    let id: UUID
    let goalId: UUID?
    let amount: Double
    let location: DreamSavingsLocation
    let occurredAt: Date
    let isDeletable: Bool
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
    let goalCategory: GoalCategory
    let locationTitle: String
    let locationSymbol: String
    let occurredAt: Date
    let subtitle: String
    let amountText: String
    let isDeletable: Bool
    let isStartingBalance: Bool
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
                    goalName: "Bali Trip",
                    goalCategory: .travel,
                    locationTitle: "Piggy bank",
                    locationSymbol: "shippingbox.fill",
                    occurredAt: .now,
                    subtitle: "Piggy bank • 9:42 AM",
                    amountText: "₹2,000",
                    isDeletable: true,
                    isStartingBalance: false
                ),
                SavedHistoryEntry(
                    id: UUID(),
                    goalName: "Gaming Setup",
                    goalCategory: .gaming,
                    locationTitle: "Bank",
                    locationSymbol: "building.columns.fill",
                    occurredAt: .now,
                    subtitle: "Bank • 7:18 AM",
                    amountText: "₹1,500",
                    isDeletable: true,
                    isStartingBalance: false
                )
            ]
        )

        let yesterday = SavedDaySection(
            title: "Yesterday",
            totalText: "+₹4,000",
            entries: [
                SavedHistoryEntry(
                    id: UUID(),
                    goalName: "Bali Trip",
                    goalCategory: .travel,
                    locationTitle: "Cash",
                    locationSymbol: "banknote.fill",
                    occurredAt: .now.addingTimeInterval(-86_400),
                    subtitle: "Cash • 6:05 PM",
                    amountText: "₹4,000",
                    isDeletable: true,
                    isStartingBalance: false
                )
            ]
        )

        return SavedHistoryViewModel(
            sections: [today, yesterday],
            availableGoals: [
                GoalFilterOption(id: UUID(), name: "Bali Trip", emoji: "🏖️", category: .travel),
                GoalFilterOption(id: UUID(), name: "Gaming Setup", emoji: "🎮", category: .gaming)
            ]
        )
    }
}
