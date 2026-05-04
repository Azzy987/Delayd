import Foundation
import Observation
import SwiftData

@Observable
final class OnboardingViewModel {
    static let totalSteps = 9

    var currentStep: Int = 0
    var selectedDream: GoalCategory?
    var goalName: String
    var goalAmount: String
    var goalDate: Date?
    var monthlyTarget: String
    var startingSavedAmount: String
    var savingsLocation: DreamSavingsLocation
    var currencyCode: String
    var notificationsEnabled: Bool
    var hapticsEnabled: Bool
    /// Emotional tone chosen in onboarding; persisted to UserSettings at the
    /// end and consumed everywhere copy is rendered (insights, reveals,
    /// notifications).
    var selectedTone: DelaydTone

    init(
        currentStep: Int = 0,
        selectedDream: GoalCategory? = nil,
        goalName: String = "",
        goalAmount: String = "120000",
        goalDate: Date? = Calendar.current.date(byAdding: .month, value: 12, to: .now),
        monthlyTarget: String = "10000",
        startingSavedAmount: String = "",
        savingsLocation: DreamSavingsLocation = .piggyBank,
        currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode,
        notificationsEnabled: Bool = false,
        hapticsEnabled: Bool = true,
        selectedTone: DelaydTone = .motivational
    ) {
        self.currentStep = currentStep
        self.selectedDream = selectedDream
        self.goalName = goalName
        self.goalAmount = goalAmount
        self.goalDate = goalDate
        self.monthlyTarget = monthlyTarget
        self.startingSavedAmount = startingSavedAmount
        self.savingsLocation = savingsLocation
        self.currencyCode = currencyCode
        self.notificationsEnabled = notificationsEnabled
        self.hapticsEnabled = hapticsEnabled
        self.selectedTone = selectedTone
    }

    func next() {
        persistDraft()

        guard currentStep < Self.totalSteps - 1 else {
            complete()
            return
        }

        currentStep += 1
    }

    func back() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    func skipPermissions() {
        notificationsEnabled = false
        persistDraft()

        if currentStep >= Self.totalSteps - 2 {
            complete()
        } else {
            currentStep += 1
        }
    }

    func complete() {
        persistDraft()
        UserDefaults.standard.set(true, forKey: Keys.completed)
    }

    func complete(modelContainer: ModelContainer) async {
        persistDraft()
        let settingsRepository = SettingsRepository(modelContainer: modelContainer)
        let goalRepository = GoalRepository(modelContainer: modelContainer)
        let contributionRepository = DreamContributionRepository(modelContainer: modelContainer)

        let category = selectedDream ?? .travel
        let name = goalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? category.label : goalName
        let targetAmount = Double(goalAmount.filter { $0.isNumber || $0 == "." }) ?? 120_000
        let monthlyAmount = Double(monthlyTarget.filter { $0.isNumber || $0 == "." }) ?? 10_000
        let startingAmount = Double(startingSavedAmount.filter { $0.isNumber || $0 == "." }) ?? 0

        let goal = await goalRepository.create(
            name: name,
            emoji: category.emoji,
            category: category,
            targetAmount: targetAmount,
            deadline: goalDate
        )

        if startingAmount > 0 {
            _ = await contributionRepository.create(
                amount: startingAmount,
                location: savingsLocation,
                note: "Starting protected amount",
                linkedGoalId: goal.id,
                occurredAt: .now,
                monthlySavingsTarget: monthlyAmount,
                currencyCode: currencyCode
            )
        }

        await settingsRepository.update { settings in
            settings.defaultCurrency = currencyCode
            settings.monthlySavingsTarget = monthlyAmount
            settings.hapticsEnabled = hapticsEnabled
            settings.notificationsEnabled = notificationsEnabled
            settings.onboardingCompleted = true
            settings.defaultGoalId = goal.id
            settings.tone = selectedTone.rawValue
        }

        UserDefaults.standard.set(true, forKey: Keys.completed)
    }

    private func persistDraft() {
        let defaults = UserDefaults.standard
        defaults.set(selectedDream?.rawValue, forKey: Keys.selectedDream)
        defaults.set(goalName, forKey: Keys.goalName)
        defaults.set(goalAmount, forKey: Keys.goalAmount)
        defaults.set(goalDate, forKey: Keys.goalDate)
        defaults.set(monthlyTarget, forKey: Keys.monthlyTarget)
        defaults.set(startingSavedAmount, forKey: Keys.startingSavedAmount)
        defaults.set(savingsLocation.rawValue, forKey: Keys.savingsLocation)
        defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
        defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
        defaults.set(selectedTone.rawValue, forKey: Keys.selectedTone)
    }
}

extension OnboardingViewModel {
    static func mock(step: Int = 0) -> OnboardingViewModel {
        OnboardingViewModel(currentStep: step, selectedDream: .travel, goalName: "Bali trip")
    }
}

private extension OnboardingViewModel {
    enum Keys {
        static let completed = "delayd.onboarding.completed"
        static let selectedDream = "delayd.onboarding.selectedDream"
        static let goalName = "delayd.onboarding.goalName"
        static let goalAmount = "delayd.onboarding.goalAmount"
        static let goalDate = "delayd.onboarding.goalDate"
        static let monthlyTarget = "delayd.onboarding.monthlyTarget"
        static let startingSavedAmount = "delayd.onboarding.startingSavedAmount"
        static let savingsLocation = "delayd.onboarding.savingsLocation"
        static let notificationsEnabled = "delayd.onboarding.notificationsEnabled"
        static let hapticsEnabled = "delayd.onboarding.hapticsEnabled"
        static let selectedTone = "delayd.onboarding.selectedTone"
    }
}
