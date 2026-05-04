import SwiftUI
import Observation
import SwiftData

@Observable
@MainActor
final class QuickLogViewModel {
    var amountText: String
    var selectedGoal: GoalSnapshot
    var selectedTag: ExpenseTag?
    var customTagTitle: String
    var expenseDate: Date
    var isLogging: Bool

    var goals: [GoalSnapshot]
    let tags: [ExpenseTag]

    private var monthlyTarget: Double
    private let calculator: DelayCalculator
    private var modelContainer: ModelContainer?
    /// ISO 4217 currency code loaded from settings. Drives the amount preview.
    /// Defaults to the device locale so the first frame matches the user's
    /// region (avoids a `$` flash before settings load on Indian devices).
    private(set) var currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode

    init(
        amountText: String = "",
        selectedGoal: GoalSnapshot? = nil,
        selectedTag: ExpenseTag? = nil,
        customTagTitle: String = "",
        expenseDate: Date = .now,
        isLogging: Bool = false,
        goals: [GoalSnapshot]? = nil,
        tags: [ExpenseTag]? = nil,
        monthlyTarget: Double = 10_000,
        calculator: DelayCalculator? = nil
    ) {
        self.amountText = amountText
        self.selectedGoal = selectedGoal ?? .mockBali
        self.selectedTag = selectedTag
        self.customTagTitle = customTagTitle
        self.expenseDate = expenseDate
        self.isLogging = isLogging
        self.goals = goals ?? [.mockBali, .mockGaming, .mockEmergency]
        self.tags = tags ?? ExpenseTag.defaultTags
        self.monthlyTarget = monthlyTarget
        self.calculator = calculator ?? DelayCalculator()
    }

    var amount: Double {
        let filtered = amountText.filter { $0.isNumber || $0 == "." }
        return Double(filtered) ?? 0
    }

    var canLog: Bool {
        amount > 0 && !isLogging
    }

    var previewImpact: DelayImpact? {
        guard amount > 0 else { return nil }
        return calculator.calculateDelay(expenseAmount: amount, goal: selectedGoal, monthlyTarget: monthlyTarget)
    }

    var needsHardModeConfirmation: Bool {
        (previewImpact?.delayDays ?? 0) >= 7
    }

    var formattedAmountPreview: String {
        let sym = CurrencyFormatter.symbol(for: currencyCode)
        guard amount > 0 else { return "\(sym)0" }
        return "\(sym)\(formatted(amount))"
    }

    func clearTag() {
        selectedTag = nil
    }

    func selectTag(_ tag: ExpenseTag) {
        selectedTag = tag
        customTagTitle = ""
    }

    func selectGoal(_ goal: GoalSnapshot) {
        selectedGoal = goal
    }

    func cycleGoal() {
        guard !goals.isEmpty else { return }

        guard let currentIndex = goals.firstIndex(of: selectedGoal) else {
            selectedGoal = goals[0]
            return
        }

        let nextIndex = goals.index(after: currentIndex)
        selectedGoal = goals[nextIndex == goals.endIndex ? goals.startIndex : nextIndex]
    }

    func load(modelContainer: ModelContainer) async {
        self.modelContainer = modelContainer
        let goalRepository = GoalRepository(modelContainer: modelContainer)
        let settingsRepository = SettingsRepository(modelContainer: modelContainer)
        let settings = await settingsRepository.fetchSnapshot()
        let snapshots = await goalRepository.fetchActiveSnapshots()

        if !snapshots.isEmpty {
            goals = snapshots
            selectedGoal = snapshots.first { $0.id == settings.defaultGoalId } ?? snapshots[0]
        }

        monthlyTarget = settings.monthlySavingsTarget
        currencyCode = settings.defaultCurrency
    }

    func logExpense() async -> DelayImpact? {
        guard canLog else { return nil }

        isLogging = true
        try? await Task.sleep(for: .milliseconds(300))
        let impact = calculator
            .calculateDelay(expenseAmount: amount, goal: selectedGoal, monthlyTarget: monthlyTarget)
            .withCurrencyCode(currencyCode)
        let persistedExpenseId: UUID?

        if let modelContainer {
            let repository = ExpenseRepository(modelContainer: modelContainer)
            let customTitle = customTagTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let tagTitle = customTitle.isEmpty ? (selectedTag?.title ?? "Other") : customTitle
            persistedExpenseId = await repository.create(
                amount: amount,
                merchant: tagTitle,
                tag: tagTitle,
                note: nil,
                linkedGoalId: selectedGoal.id,
                occurredAt: expenseDate
            )
        } else {
            persistedExpenseId = nil
        }

        isLogging = false
        if let persistedExpenseId {
            return impact.withExpenseId(persistedExpenseId)
        }
        return impact
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

struct ExpenseTag: Identifiable, Equatable {
    let id: String
    let title: String
    let variant: TagChip.Variant

    init(_ title: String, variant: TagChip.Variant = .purple) {
        self.id = title
        self.title = title
        self.variant = variant
    }
}

extension ExpenseTag {
    static func == (lhs: ExpenseTag, rhs: ExpenseTag) -> Bool {
        lhs.id == rhs.id
    }
}

extension ExpenseTag {
    static let dining = ExpenseTag("Dinner", variant: .warning)
    static let coffee = ExpenseTag("Coffee", variant: .purple)
    static let shopping = ExpenseTag("Shopping", variant: .warning)
    static let travel = ExpenseTag("Travel", variant: .purple)
    static let health = ExpenseTag("Health", variant: .positive)

    static let defaultTags: [ExpenseTag] = [
        .dining,
        .coffee,
        .shopping,
        .travel,
        .health
    ]
}

extension QuickLogViewModel {
    static func mock(amount: String = "500") -> QuickLogViewModel {
        QuickLogViewModel(amountText: amount)
    }
}

#Preview("Quick Log View Model") {
    Text(QuickLogViewModel.mock().formattedAmountPreview)
        .font(.system(size: 40, weight: .bold, design: .monospaced))
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
