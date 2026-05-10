import AppIntents
import Foundation
import Observation
import SwiftData
import SwiftUI

/// Shortcut-facing intent that opens Delayd straight into the Quick Log sheet
/// with the amount pre-filled. Also powers the back-tap workflow the user set
/// up via Accessibility → Touch → Back Tap → "Run Shortcut".
///
/// Intentional scope: we DON'T persist silently from the intent. Delayd's
/// whole mechanic is the reveal animation that makes the delay viscerally
/// felt — silently logging would skip the emotional payoff. So this intent
/// deep-links into the in-app sheet instead.
///
/// Lives in the main app target so it's available to Shortcuts, Siri, and
/// back-tap without requiring the widget extension to be installed.
@available(iOS 17.0, *)
struct QuickLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Quick Log"
    static let description = IntentDescription(
        "Open Delayd straight into Quick Log with the amount pre-filled.",
        categoryName: "Logging"
    )

    /// When true, iOS brings the app to the foreground so the user sees the
    /// reveal animation after logging. We always want this for Quick Log.
    static let openAppWhenRun = true

    @Parameter(
        title: "Amount",
        description: "How much did you spend? (in your default currency)",
        controlStyle: .field,
        inclusiveRange: (0.0, 10_000_000.0)
    )
    var amount: Double?

    init() {}

    init(amount: Double?) {
        self.amount = amount
    }

    func perform() async throws -> some IntentResult {
        // Hand off to the app. RootView reads the pending amount on next
        // scene-activation and presents QuickLogSheet. The actual log + reveal
        // still happens in-app so the user feels the delay.
        await MainActor.run {
            QuickLogIntentBridge.shared.requestQuickLog(amount: amount)
        }
        return .result()
    }
}

@available(iOS 17.0, *)
enum ShortcutMerchantPreset: String, AppEnum {
    case coffee
    case food
    case shopping
    case transport
    case travel
    case health
    case other

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Spend Type")

    static let caseDisplayRepresentations: [ShortcutMerchantPreset: DisplayRepresentation] = [
        .coffee: DisplayRepresentation(title: "Coffee"),
        .food: DisplayRepresentation(title: "Food"),
        .shopping: DisplayRepresentation(title: "Shopping"),
        .transport: DisplayRepresentation(title: "Transport"),
        .travel: DisplayRepresentation(title: "Travel"),
        .health: DisplayRepresentation(title: "Health"),
        .other: DisplayRepresentation(title: "Other")
    ]

    var merchantLabel: String {
        switch self {
        case .coffee: "Coffee"
        case .food: "Food"
        case .shopping: "Shopping"
        case .transport: "Transport"
        case .travel: "Travel"
        case .health: "Health"
        case .other: "Other"
        }
    }

    /// Display label used in the Shortcuts snippet's "Category" row.
    /// Slightly more presentable than the bare merchant label (e.g. groups
    /// coffee + food together as "Food & Drinks").
    var categoryLabel: String {
        switch self {
        case .coffee, .food: "Food & Drinks"
        case .shopping: "Shopping"
        case .transport: "Transport"
        case .travel: "Travel"
        case .health: "Health"
        case .other: "Other"
        }
    }
}

@available(iOS 17.0, *)
enum ShortcutPaymentMethod: String, AppEnum {
    case cash
    case card
    case upi
    case wallet
    case other

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Payment Method")

    static let caseDisplayRepresentations: [ShortcutPaymentMethod: DisplayRepresentation] = [
        .cash: DisplayRepresentation(title: "Cash"),
        .card: DisplayRepresentation(title: "Card"),
        .upi: DisplayRepresentation(title: "UPI"),
        .wallet: DisplayRepresentation(title: "Wallet"),
        .other: DisplayRepresentation(title: "Other")
    ]

    var label: String {
        switch self {
        case .cash: "Cash"
        case .card: "Card"
        case .upi: "UPI"
        case .wallet: "Wallet"
        case .other: "Other"
        }
    }
}

@available(iOS 17.0, *)
struct QuickCaptureExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Delayd Log Expense"
    static let description = IntentDescription(
        "Capture a spend from Shortcuts, Back Tap, Action Button, or Lock Screen controls and return its dream delay.",
        categoryName: "Logging"
    )
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(
        title: "Amount",
        description: "How much did you spend?",
        controlStyle: .field,
        inclusiveRange: (0.0, 10_000_000.0)
    )
    var amount: Double?

    @Parameter(
        title: "Spend Type",
        description: "Choose a quick chip for what this spend was."
    )
    var merchantPreset: ShortcutMerchantPreset?

    @Parameter(
        title: "Custom Merchant",
        description: "Optional. Use this when Spend Type is Other or when you want a specific merchant name."
    )
    var customMerchant: String?

    @Parameter(
        title: "Payment Method",
        description: "How was this paid? Shown in the confirmation card."
    )
    var paymentMethod: ShortcutPaymentMethod?

    @Parameter(
        title: "Date",
        description: "When did this spend happen?"
    )
    var expenseDate: Date?

    init() {
        amount = nil
        merchantPreset = nil
        customMerchant = nil
        paymentMethod = nil
        expenseDate = nil
    }

    init(
        amount: Double,
        merchantPreset: ShortcutMerchantPreset,
        customMerchant: String? = nil,
        paymentMethod: ShortcutPaymentMethod = .cash,
        expenseDate: Date = .now
    ) {
        self.amount = amount
        self.merchantPreset = merchantPreset
        self.customMerchant = customMerchant
        self.paymentMethod = paymentMethod
        self.expenseDate = expenseDate
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let capturedAmount: Double
        if let amount, amount > 0 {
            capturedAmount = amount
        } else {
            capturedAmount = try await $amount.requestValue("What is the amount?")
        }

        guard capturedAmount > 0 else {
            return .result(
                dialog: "Enter an amount greater than 0.",
                view: emptyResultView(message: "Amount must be greater than 0.")
            )
        }

        let capturedPreset = if let merchantPreset {
            merchantPreset
        } else {
            try await $merchantPreset.requestValue("What did you spend on?")
        }

        let capturedMerchant = try await resolvedMerchant(for: capturedPreset)
        let capturedDate = if let expenseDate {
            expenseDate
        } else {
            try await $expenseDate.requestValue("When did this spend happen?")
        }
        let capturedPayment = paymentMethod ?? .cash

        let container = try Self.makeModelContainer()
        let settingsRepository = SettingsRepository(modelContainer: container)
        let goalRepository = GoalRepository(modelContainer: container)
        let expenseRepository = ExpenseRepository(modelContainer: container)
        let settings = await settingsRepository.fetchSnapshot()
        let goals = await goalRepository.fetchActive()

        guard let goal = goals.first(where: { $0.id == settings.defaultGoalId }) ?? goals.first else {
            return .result(
                dialog: "Create a dream in Delayd before using Quick Capture.",
                view: emptyResultView(message: "Open Delayd and create a dream first.")
            )
        }

        let calculator = DelayCalculator()
        let impact = calculator.calculateDelay(
            expenseAmount: capturedAmount,
            goal: goal,
            monthlyTarget: settings.monthlySavingsTarget
        )
        let amountText = CurrencyFormatter.format(capturedAmount, currencyCode: settings.defaultCurrency)
        let goalName = goal.name.delaydGoalTitleCased
        let confirmationDialog = shortcutConfirmationDialog(
            amountText: amountText,
            goalName: goalName,
            delayDays: impact.delayDays
        )

        let didConfirm = try await $amount.requestConfirmation(
            for: capturedAmount,
            dialog: confirmationDialog
        ) {
            QuickCaptureConfirmationSnippet(
                amountText: amountText,
                merchant: capturedMerchant,
                spendType: capturedPreset.categoryLabel,
                dreamName: goalName,
                paymentLabel: capturedPayment.label,
                expenseDate: capturedDate,
                delayDays: impact.delayDays
            )
        }
        guard didConfirm else {
            return .result(
                dialog: "Expense not logged.",
                view: emptyResultView(message: "Expense not logged.")
            )
        }

        let expenseId = await expenseRepository.create(
            amount: capturedAmount,
            merchant: capturedMerchant,
            tag: capturedPreset.merchantLabel,
            note: nil,
            linkedGoalId: goal.id,
            occurredAt: capturedDate
        )
        await expenseRepository.applyImpact(
            goalId: goal.id,
            expenseId: expenseId,
            delayDays: impact.delayDays,
            previousProgress: impact.previousProgress,
            newProgress: impact.newProgress,
            newAmount: impact.newAmount
        )

        // Tell the running app (if any) that data changed so HomeView /
        // HistoryView can refresh the moment the user comes back from
        // Shortcuts. The intent runs out-of-process when invoked from the
        // Shortcuts app, so a Darwin notification is the right cross-process
        // signal here. RootView listens for this notification.
        QuickCaptureBroadcast.postDidLogExpense()

        // Pull from `ImpactRevealCopy` — the same source of truth used by
        // the in-app `DelayedImpactRevealViewModel`. Same expense ⇒ same
        // message in app + Shortcut, with severity scaled by both the
        // delay days and the spend's weight relative to the user's
        // monthly target (so a ₹5,000 spend reads "major" even on 1 day).
        let toneMessage: String? = impact.delayDays > 0
            ? ImpactRevealCopy.line(
                tone: settings.tone,
                days: impact.delayDays,
                amount: capturedAmount,
                monthlyTarget: settings.monthlySavingsTarget,
                goalName: goalName
            )
            : nil

        let resultDialog: IntentDialog
        if let toneMessage {
            resultDialog = IntentDialog("\(amountText) logged. \(toneMessage)")
        } else {
            resultDialog = IntentDialog("\(amountText) logged. \(goalName) is still on track.")
        }

        return .result(dialog: resultDialog) {
            QuickCaptureResultSnippet(
                amountText: amountText,
                dreamName: goalName,
                delayDays: impact.delayDays,
                toneMessage: toneMessage
            )
        }
    }

    /// Fallback view used when we have to bail out before showing the rich
    /// confirmation card (e.g. invalid amount, no dream configured). Keeps a
    /// consistent visual language inside Shortcuts.
    @ViewBuilder
    private func emptyResultView(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
    }

    private func resolvedMerchant(for preset: ShortcutMerchantPreset) async throws -> String {
        let trimmed = customMerchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty else { return trimmed }
        guard preset == .other else { return preset.merchantLabel }

        let merchant = try await $customMerchant.requestValue("What is the expense about?")
        let normalized = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? preset.merchantLabel : normalized
    }

    private func shortcutConfirmationDialog(
        amountText: String,
        goalName: String,
        delayDays: Int
    ) -> IntentDialog {
        // Single short prompt above the snippet card. Voice (Siri) reads
        // this; the visual UI shows the snippet view, so we keep this brief.
        if delayDays == 0 {
            return IntentDialog("Log \(amountText)? \(goalName) stays on track.")
        }
        return IntentDialog("Log \(amountText)? This pushes \(goalName) back by \(delayDays) \(delayDays == 1 ? "day" : "days").")
    }

    private static func makeModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Goal.self,
            DreamContribution.self,
            Expense.self,
            ImpactEvent.self,
            UserSettings.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(
            for: schema,
            migrationPlan: DelaydMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

/// Cross-process broadcast hub used by `QuickCaptureExpenseIntent` to tell
/// the main app that an expense was just written to SwiftData. Because the
/// intent can run inside the Shortcuts app (a different process) when
/// `openAppWhenRun = false`, in-process notifications wouldn't reach the
/// running app — we use a Darwin notification, which is cross-process.
///
/// `RootView` observes this notification and bumps `homeRefreshToken` so the
/// home cards reflect the new expense the moment the user comes back to
/// Delayd. Also posts a same-process `Notification` so views inside the
/// running app process (when the intent runs in-process) can react too.
enum QuickCaptureBroadcast {
    /// Darwin notification name. Must be a stable string both processes know.
    static let darwinName = "com.delayd.quickCapture.didLogExpense"

    /// Foundation notification name for in-process listeners.
    static let foundationName = Notification.Name("delayd.quickCapture.didLogExpense")

    static func postDidLogExpense() {
        // Cross-process Darwin notification (reaches the app even when this
        // intent runs inside the Shortcuts process).
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(darwinName as CFString),
            nil,
            nil,
            true
        )
        // In-process notification (reaches RootView immediately if the intent
        // happened to run in the app process, e.g. via Siri while open).
        NotificationCenter.default.post(name: foundationName, object: nil)
    }

    /// Subscribe to the Darwin notification with a callback that fires on the
    /// main thread. Returns a token that, when deallocated, unregisters.
    /// Used by `RootView` to refresh the home cards after a Shortcut log.
    @MainActor
    static func observeDidLogExpense(_ handler: @escaping @MainActor () -> Void) -> DarwinObserverToken {
        let token = DarwinObserverToken(name: darwinName) {
            Task { @MainActor in handler() }
        }
        return token
    }
}

/// RAII wrapper for a Darwin notification observer. Registers on init,
/// unregisters on deinit. Hold this in a `@State` property to keep the
/// subscription alive for the view's lifetime.
final class DarwinObserverToken {
    private let name: String
    private let handler: () -> Void
    private var observer: UnsafeRawPointer?

    init(name: String, handler: @escaping () -> Void) {
        self.name = name
        self.handler = handler
        let unmanaged = Unmanaged.passUnretained(self)
        let observerPointer = unmanaged.toOpaque()
        self.observer = UnsafeRawPointer(observerPointer)

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observerPointer,
            { _, opaqueObserver, _, _, _ in
                guard let opaqueObserver else { return }
                let token = Unmanaged<DarwinObserverToken>
                    .fromOpaque(opaqueObserver)
                    .takeUnretainedValue()
                token.handler()
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        if let observer {
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                observer,
                CFNotificationName(name as CFString),
                nil
            )
        }
    }
}

/// Thread-safe hand-off between the App Intent (which runs outside the normal
/// view hierarchy) and the SwiftUI scene. RootView observes this singleton
/// and presents the sheet when a request comes in.
///
/// Uses the modern `@Observable` macro so RootView can react with
/// `.onChange(of: bridge.requestToken)` without pulling in Combine.
@Observable
@MainActor
final class QuickLogIntentBridge {
    static let shared = QuickLogIntentBridge()

    /// The amount the intent wants pre-filled. Cleared by RootView once
    /// consumed so re-invocations aren't ignored.
    var pendingAmount: Double?
    /// Monotonic counter so the view reliably observes repeated requests even
    /// when `pendingAmount` happens to be the same value twice in a row.
    var requestToken: Int = 0

    private init() {}

    func requestQuickLog(amount: Double?) {
        pendingAmount = amount
        requestToken &+= 1
    }

    func consume() -> Double? {
        let value = pendingAmount
        pendingAmount = nil
        return value
    }
}

/// Exposes the intent to Spotlight/Shortcuts with suggested phrases. iOS uses
/// these as hint strings ("Hey Siri, log expense in Delayd…") and also to
/// bootstrap the Shortcuts app with a pre-built shortcut the user can adopt
/// in one tap.
@available(iOS 17.0, *)
struct DelaydAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickCaptureExpenseIntent(),
            phrases: [
                "\(.applicationName) log expense",
                "Log expense in \(.applicationName)",
                "Quick log expense in \(.applicationName)",
            ],
            shortTitle: "Log Expense",
            systemImageName: "clock.badge.plus"
        )
    }
}
