import SwiftUI
import Observation
import SwiftData

@Observable
@MainActor
final class DelayedImpactRevealViewModel {
    let impact: DelayImpact

    var showBackground = false
    var showAmount = false
    var showImpactLine = false
    var showDays = false
    var showProgress = false
    var showSuggestion = false
    var showActions = false
    var displayedDelayDays = 0
    var undoCountdown = 5
    var isUndoVisible = false
    /// Tone-aware one-liner shown in the suggestion card. Defaults to the
    /// impact's hard-coded `suggestion` until settings resolve, then swaps in
    /// the correct voice from `ToneCopy`.
    var toneMessage: String

    private var hasStarted = false
    private var hasPersistedImpact = false
    private let hapticService: HapticService

    init(impact: DelayImpact, hapticService: HapticService? = nil) {
        self.impact = impact
        self.hapticService = hapticService ?? HapticService()
        self.toneMessage = impact.suggestion
    }

    func startReveal(modelContainer: ModelContainer? = nil) async {
        guard !hasStarted else { return }
        hasStarted = true

        // Resolve the user's chosen tone before the suggestion card animates in
        // so the first copy the user sees is in the right voice (no flash of
        // default text). Pulls from `ImpactRevealCopy` — single source of
        // truth shared with the Shortcut result snippet so the same expense
        // shows the same message in both places.
        if let modelContainer {
            let settingsRepository = SettingsRepository(modelContainer: modelContainer)
            let snapshot = await settingsRepository.fetchSnapshot()
            monthlyTarget = snapshot.monthlySavingsTarget
            toneMessage = ImpactRevealCopy.line(
                tone: snapshot.tone,
                days: impact.delayDays,
                amount: impact.amount,
                monthlyTarget: snapshot.monthlySavingsTarget,
                goalName: impact.affectedGoal.name.delaydGoalTitleCased
            )
        }

        withAnimation(.easeOut(duration: 0.2)) {
            showBackground = true
        }

        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.easeOut(duration: 0.3)) {
            showAmount = true
        }

        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(.easeOut(duration: 0.2)) {
            showImpactLine = true
        }

        try? await Task.sleep(for: .milliseconds(200))
        withAnimation(.easeOut(duration: 0.2)) {
            showDays = true
            showProgress = true
        }

        Task {
            await animateDelayCount()
        }

        try? await Task.sleep(for: .milliseconds(600))
        hapticService.playWarning()
        Task {
            await persistImpactIfNeeded(modelContainer: modelContainer)
        }

        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.easeOut(duration: 0.3)) {
            showSuggestion = true
        }

        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.easeOut(duration: 0.3)) {
            showActions = true
            isUndoVisible = true
        }

        Task {
            await startUndoCountdown()
        }
    }

    private func persistImpactIfNeeded(modelContainer: ModelContainer?) async {
        guard !hasPersistedImpact, let modelContainer else { return }
        guard let expenseId = impact.expenseId else { return }
        hasPersistedImpact = true
        let goalId = impact.affectedGoal.id
        let delayDays = impact.delayDays
        let previousProgress = impact.previousProgress
        let newProgress = impact.newProgress
        let newAmount = impact.newAmount
        let repository = ExpenseRepository(modelContainer: modelContainer)
        await repository.applyImpact(
            goalId: goalId,
            expenseId: expenseId,
            delayDays: delayDays,
            previousProgress: previousProgress,
            newProgress: newProgress,
            newAmount: newAmount
        )
    }

    private func animateDelayCount() async {
        let finalValue = max(impact.delayDays, 1)
        let steps = min(max(finalValue, 12), 40)
        let interval = 600 / steps

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            displayedDelayDays = max(1, Int((Double(finalValue) * progress).rounded()))
            try? await Task.sleep(for: .milliseconds(interval))
        }

        displayedDelayDays = finalValue
    }

    private func startUndoCountdown() async {
        undoCountdown = 5

        while undoCountdown > 0 {
            try? await Task.sleep(for: .seconds(1))
            undoCountdown -= 1
        }

        withAnimation(.easeOut(duration: 0.25)) {
            isUndoVisible = false
        }
    }

    var amountText: String {
        CurrencyFormatter.format(impact.amount, currencyCode: impact.currencyCode)
    }

    var delayText: String {
        "\(displayedDelayDays) \(displayedDelayDays == 1 ? "day" : "days")"
    }

    var timelineShiftText: String? {
        guard let originalDate = impact.affectedGoal.targetDate else { return nil }
        let days = max(impact.delayDays, 1)
        guard let shiftedDate = Calendar.current.date(byAdding: .day, value: days, to: originalDate) else {
            return nil
        }

        return "Now \(formattedDate(shiftedDate)) instead of \(formattedDate(originalDate))"
    }

    var impactLeadText: String {
        switch severity {
        case .light:
            "nudged your"
        case .moderate:
            "pushed back your"
        case .serious:
            "seriously delayed your"
        case .major:
            "hit your"
        }
    }

    /// Monthly savings target captured at reveal time so `severity` can stay
    /// amount-aware (a ₹5,000 spend reads "major" even on a low day count).
    /// Defaults to a sane value before settings load; `startReveal` updates
    /// it from `UserSettings`.
    private var monthlyTarget: Double = 10_000

    var amountShiftText: String {
        if hasProgressMovement {
            return "\(CurrencyFormatter.format(impact.previousAmount, currencyCode: impact.currencyCode)) → \(CurrencyFormatter.format(impact.newAmount, currencyCode: impact.currencyCode)) saved"
        }

        return "Timeline moved \(max(impact.delayDays, 1)) \(impact.delayDays == 1 ? "day" : "days") further away"
    }

    var hasProgressMovement: Bool {
        abs(impact.previousProgress - impact.newProgress) > 0.001
    }

    var delayMeterProgress: Double {
        min(max(Double(max(impact.delayDays, 1)) / 30.0, 0.12), 1)
    }

    private func formatCurrencyNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    /// Severity used by `impactLeadText` ("nudged" / "hit") and the reveal
    /// view's visual emphasis. Delegates to the shared `ImpactSeverity` so
    /// the in-app reveal and the Shortcut snippet stay aligned: an expense
    /// classified as "major" will read "hit your goal" here AND surface a
    /// major-tier line from `ImpactRevealCopy`.
    private var severity: ImpactSeverity {
        let weightRatio = monthlyTarget > 0 ? impact.amount / monthlyTarget : 0
        return ImpactSeverity.classify(delayDays: impact.delayDays, weightRatio: weightRatio)
    }
}

extension DelayedImpactRevealViewModel {
    static func mockSmall() -> DelayedImpactRevealViewModel {
        DelayedImpactRevealViewModel(impact: .mockSmall)
    }

    static func mockMedium() -> DelayedImpactRevealViewModel {
        DelayedImpactRevealViewModel(impact: .mockMedium)
    }

    static func mockLarge() -> DelayedImpactRevealViewModel {
        DelayedImpactRevealViewModel(impact: .mockLarge)
    }

    static func mockEmergency() -> DelayedImpactRevealViewModel {
        DelayedImpactRevealViewModel(impact: .mockEmergency)
    }
}

#Preview("Reveal View Model") {
    Text(DelayedImpactRevealViewModel.mockMedium().amountText)
        .font(.system(size: 40, weight: .bold, design: .monospaced))
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
