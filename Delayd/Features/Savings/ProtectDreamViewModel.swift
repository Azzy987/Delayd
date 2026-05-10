import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ProtectDreamViewModel {
    enum ProtectSource: String, CaseIterable, Identifiable {
        case salaryLeftover = "Salary leftover"
        case sideHustle = "Side hustle"
        case investment = "Investment"
        case cashback = "Cashback"
        case gift = "Gift"
        case other = "Other"

        var id: String { rawValue }
    }

    var amountText: String
    var selectedGoal: GoalSnapshot
    var selectedLocation: DreamSavingsLocation
    var selectedSource: ProtectSource?
    var protectedDate: Date
    var isSaving: Bool
    var goals: [GoalSnapshot]

    private var monthlyTarget: Double
    private var modelContainer: ModelContainer?
    private(set) var currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode

    init(
        amountText: String = "",
        selectedGoal: GoalSnapshot? = nil,
        selectedLocation: DreamSavingsLocation = .piggyBank,
        selectedSource: ProtectSource? = nil,
        protectedDate: Date = .now,
        isSaving: Bool = false,
        goals: [GoalSnapshot]? = nil,
        monthlyTarget: Double = 10_000
    ) {
        self.amountText = amountText
        self.selectedGoal = selectedGoal ?? .mockBali
        self.selectedLocation = selectedLocation
        self.selectedSource = selectedSource
        self.protectedDate = protectedDate
        self.isSaving = isSaving
        self.goals = goals ?? [.mockBali, .mockGaming, .mockEmergency]
        self.monthlyTarget = monthlyTarget
    }

    var amount: Double {
        Double(amountText.filter { $0.isNumber || $0 == "." }) ?? 0
    }

    var canSave: Bool {
        amount > 0 && !isSaving
    }

    var formattedAmountPreview: String {
        let symbol = CurrencyFormatter.symbol(for: currencyCode)
        guard amount > 0 else { return "\(symbol)0" }
        return "\(symbol)\(formatted(amount))"
    }

    var previewDaysCloser: Int {
        guard amount > 0 else { return 0 }
        if let targetDate = selectedGoal.targetDate {
            let today = Calendar.current.startOfDay(for: .now)
            let targetDay = Calendar.current.startOfDay(for: targetDate)
            let daysRemaining = Calendar.current.dateComponents([.day], from: today, to: targetDay).day ?? 0
            let remaining = max(selectedGoal.targetAmount - selectedGoal.currentAmount, 0)

            if daysRemaining > 0, remaining > 0 {
                let requiredDaily = max(remaining / Double(daysRemaining), 1)
                return max(1, Int(ceil(amount / requiredDaily)))
            }
        }

        let dailyTarget = max(monthlyTarget, 1) / 30.0
        return max(1, Int(ceil(amount / dailyTarget)))
    }

    var encouragementLine: String {
        guard amount > 0 else {
            return "Protect even a small amount and your dream moves closer."
        }
        let dayWord = previewDaysCloser == 1 ? "day" : "days"
        return "\(formattedAmountPreview) moves \(selectedGoal.name.delaydGoalTitleCased) \(previewDaysCloser) \(dayWord) closer."
    }

    func selectGoal(_ goal: GoalSnapshot) {
        selectedGoal = goal
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

    func protectDream() async -> DreamBoostImpact? {
        guard canSave, let modelContainer else { return nil }
        isSaving = true
        try? await Task.sleep(for: .milliseconds(240))

        let repository = DreamContributionRepository(modelContainer: modelContainer)
        let impact = await repository.create(
            amount: amount,
            location: selectedLocation,
            note: selectedSource?.rawValue,
            linkedGoalId: selectedGoal.id,
            occurredAt: protectedDate,
            monthlySavingsTarget: monthlyTarget,
            currencyCode: currencyCode
        )

        isSaving = false
        return impact
    }

    private func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

extension ProtectDreamViewModel {
    static func mock(amount: String = "5000") -> ProtectDreamViewModel {
        ProtectDreamViewModel(amountText: amount)
    }
}
