import SwiftUI
import Observation
import SwiftData

@Observable
final class HistoryViewModel {
    /// Coarse date filters surfaced in the History filter bar.
    /// `.allTime` is the no-op default that matches "show everything".
    enum DateRange: String, CaseIterable, Identifiable {
        case last7Days = "Last 7 days"
        case last30Days = "Last 30 days"
        case thisMonth = "This Month"
        case allTime = "All Time"

        var id: String { rawValue }

        /// The earliest expense date to include. `nil` means no lower bound.
        func startDate(now: Date = .now) -> Date? {
            let calendar = Calendar.current
            switch self {
            case .last7Days:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .last30Days:
                return calendar.date(byAdding: .day, value: -30, to: now)
            case .thisMonth:
                return calendar.dateInterval(of: .month, for: now)?.start
            case .allTime:
                return nil
            }
        }
    }

    var sections: [HistoryDaySection]
    /// `nil` selectedGoalId means "All goals". Otherwise filter by this Goal.id.
    var selectedGoalId: UUID?
    var selectedRange: DateRange = .last30Days
    /// Goals available for filtering — populated from the SwiftData store.
    var availableGoals: [GoalFilterOption] = []

    /// Cached unfiltered expenses as value snapshots. Do not keep SwiftData
    /// model instances here; Settings can wipe/reseed the store, which
    /// invalidates live model objects after SwiftData resets its context.
    private var allExpenses: [ExpenseSnapshot] = []
    private var settingsSnapshot: UserSettingsSnapshot?

    init(
        sections: [HistoryDaySection] = [],
        selectedGoalId: UUID? = nil,
        selectedRange: DateRange = .last30Days,
        availableGoals: [GoalFilterOption] = []
    ) {
        self.sections = sections
        self.selectedGoalId = selectedGoalId
        self.selectedRange = selectedRange
        self.availableGoals = availableGoals
    }

    var isEmpty: Bool {
        sections.isEmpty
    }

    var selectedGoalTitle: String {
        guard let selectedGoalId,
              let match = availableGoals.first(where: { $0.id == selectedGoalId }) else {
            return "All Goals"
        }
        return match.name
    }

    var selectedRangeTitle: String {
        selectedRange.rawValue
    }

    /// Called from the View when the user picks a goal from the dropdown.
    /// Re-applies filters in-place; no DB roundtrip.
    func selectGoal(_ goalId: UUID?) {
        selectedGoalId = goalId
        rebuildSections()
    }

    func selectRange(_ range: DateRange) {
        selectedRange = range
        rebuildSections()
    }

    func deleteExpense(id: UUID, modelContainer: ModelContainer) async {
        let repository = ExpenseRepository(modelContainer: modelContainer)
        await repository.delete(id: id)
        allExpenses.removeAll { $0.id == id }
        rebuildSections()
    }

    func load(modelContainer: ModelContainer) async {
        let expenseRepository = ExpenseRepository(modelContainer: modelContainer)
        let settingsRepository = SettingsRepository(modelContainer: modelContainer)
        let goalRepository = GoalRepository(modelContainer: modelContainer)

        allExpenses = await expenseRepository.fetchAllSnapshots(in: nil)
        settingsSnapshot = await settingsRepository.fetchSnapshot()
        let goals = await goalRepository.fetchActive()
        availableGoals = goals.map { GoalFilterOption(id: $0.id, name: $0.name, emoji: $0.emoji) }

        rebuildSections()
    }

    /// Apply the current `selectedGoalId` + `selectedRange` to `allExpenses`
    /// and group into day sections. Called from `load()` and any filter
    /// mutator.
    private func rebuildSections() {
        guard let snapshot = settingsSnapshot else {
            sections = []
            return
        }

        let calculator = DelayCalculator()
        let rangeStart = selectedRange.startDate()
        let filtered = allExpenses.filter { expense in
            if let rangeStart, expense.occurredAt < rangeStart { return false }
            if let selectedGoalId, expense.goalId != selectedGoalId { return false }
            return true
        }

        let grouped = Dictionary(grouping: filtered) { expense in
            Calendar.current.startOfDay(for: expense.occurredAt)
        }

        sections = grouped
            .sorted { $0.key > $1.key }
            .map { day, expenses in
                let impacts = expenses
                    .sorted { $0.occurredAt > $1.occurredAt }
                    .map { expense in
                        let delayDays = calculator.delayDays(
                            forExpense: Decimal(expense.amount),
                            monthlySavingsTarget: Decimal(snapshot.monthlySavingsTarget)
                        )
                        return HistoryImpact(
                            expenseId: expense.id,
                            category: expense.goalCategory ?? .custom,
                            expenseIconSystemImage: Self.expenseIcon(for: expense),
                            merchantName: expense.displayName,
                            goalName: expense.goalName ?? "Dream",
                            delayText: "\(delayDays) \(delayDays == 1 ? "day" : "days")",
                            amountText: CurrencyFormatter.formatNegative(expense.amount, currencyCode: snapshot.defaultCurrency),
                            occurredAt: expense.occurredAt,
                            amount: expense.amount,
                            delayDays: delayDays
                        )
                    }
                return HistoryDaySection(
                    title: Self.title(for: day),
                    totalSpent: expenses.reduce(0) { $0 + $1.amount },
                    totalDelayDays: impacts.reduce(0) { total, impact in
                        total + (Int(impact.delayText.components(separatedBy: " ").first ?? "0") ?? 0)
                    },
                    impacts: impacts,
                    currencyCode: snapshot.defaultCurrency
                )
            }
    }

    private static func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return "Today"
        }
        if calendar.isDateInYesterday(day) {
            return "Yesterday"
        }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    private static func expenseIcon(for expense: ExpenseSnapshot) -> String {
        let label = "\(expense.tag ?? "") \(expense.merchant ?? "")".lowercased()

        if label.contains("coffee") || label.contains("cafe") || label.contains("tea") {
            return "cup.and.saucer.fill"
        }
        if label.contains("dinner") || label.contains("lunch") || label.contains("food") || label.contains("restaurant") {
            return "fork.knife"
        }
        if label.contains("shopping") || label.contains("shop") || label.contains("store") {
            return "bag.fill"
        }
        if label.contains("cab") || label.contains("ride") || label.contains("uber") || label.contains("taxi") {
            return "car.fill"
        }
        if label.contains("travel") || label.contains("flight") || label.contains("trip") {
            return "airplane"
        }
        if label.contains("health") || label.contains("medical") || label.contains("medicine") {
            return "cross.case.fill"
        }
        if label.contains("movie") || label.contains("cinema") || label.contains("entertainment") {
            return "popcorn.fill"
        }
        if label.contains("headphone") || label.contains("gaming") || label.contains("game") {
            return "headphones"
        }
        if label.contains("course") || label.contains("book") || label.contains("education") {
            return "book.closed.fill"
        }

        return "creditcard.fill"
    }
}

/// Lightweight, view-friendly projection of a Goal used to populate the
/// History "filter by goal" dropdown. We don't pass `Goal` directly so the
/// VM stays decoupled from SwiftData model identity in the UI layer.
struct GoalFilterOption: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let emoji: String
}

struct HistoryDaySection: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var totalSpent: Double
    var totalDelayDays: Int
    var impacts: [HistoryImpact]
    var currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode

    var summaryText: String {
        let formatted = CurrencyFormatter.format(totalSpent, currencyCode: currencyCode)
        return "Spent: \(formatted) • Delayed: \(totalDelayDays) days"
    }
}

struct HistoryImpact: Identifiable, Equatable {
    let id = UUID()
    /// The `Expense.id` this impact maps to — used for real delete operations.
    var expenseId: UUID?
    var category: GoalCategory
    var expenseIconSystemImage: String = "creditcard.fill"
    var merchantName: String
    var goalName: String
    var delayText: String
    var amountText: String
    var occurredAt: Date = .now
    var amount: Double = 0
    var delayDays: Int = 0
}

extension HistoryDaySection {
    static let mockSections: [HistoryDaySection] = [
        HistoryDaySection(
            title: "Today",
            totalSpent: 1_240,
            totalDelayDays: 4,
            impacts: [
                HistoryImpact(category: .travel, merchantName: "Blue Tokai Coffee", goalName: "Bali trip", delayText: "1 day", amountText: "-₹250"),
                HistoryImpact(category: .home, merchantName: "Lunch with team", goalName: "House by the Sea", delayText: "2 days", amountText: "-₹650"),
                HistoryImpact(category: .travel, merchantName: "Cab ride", goalName: "Bali trip", delayText: "1 day", amountText: "-₹340")
            ]
        ),
        HistoryDaySection(
            title: "Yesterday",
            totalSpent: 2_500,
            totalDelayDays: 8,
            impacts: [
                HistoryImpact(category: .gaming, merchantName: "Headphones", goalName: "Gaming setup", delayText: "6 days", amountText: "-₹1,900"),
                HistoryImpact(category: .education, merchantName: "Course add-on", goalName: "Save for Education", delayText: "2 days", amountText: "-₹600")
            ]
        ),
        HistoryDaySection(
            title: "Mar 14, 2026",
            totalSpent: 780,
            totalDelayDays: 3,
            impacts: [
                HistoryImpact(category: .savings, merchantName: "Movie night", goalName: "Health Savings", delayText: "1 day", amountText: "-₹280"),
                HistoryImpact(category: .vacation, merchantName: "Dinner out", goalName: "Vacation fund", delayText: "2 days", amountText: "-₹500")
            ]
        )
    ]
}

extension HistoryViewModel {
    static func mock() -> HistoryViewModel {
        HistoryViewModel(
            sections: HistoryDaySection.mockSections,
            availableGoals: [
                GoalFilterOption(id: UUID(), name: "Bali trip", emoji: GoalCategory.travel.emoji),
                GoalFilterOption(id: UUID(), name: "New car", emoji: GoalCategory.vehicle.emoji),
                GoalFilterOption(id: UUID(), name: "Gaming setup", emoji: GoalCategory.gaming.emoji)
            ]
        )
    }

    static func empty() -> HistoryViewModel {
        HistoryViewModel(sections: [])
    }
}

#Preview("History View Model") {
    Text(HistoryViewModel.mock().sections.first?.summaryText ?? "No history")
        .font(AppTypography.bodyMedium)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
