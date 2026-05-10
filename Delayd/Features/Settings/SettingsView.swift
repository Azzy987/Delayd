import SwiftUI
import SwiftData
import UIKit
import StoreKit
import RevenueCatUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var isProSheetPresented = false
    @State private var isCustomerCenterPresented = false
    @State private var isTonePickerPresented = false
    @State private var isThemePickerPresented = false
    @State private var activeSettingsSheet: SettingsUtilitySheet?
    @State private var isCreateGoalPresented = false
    @State private var isNotificationDeniedAlertPresented = false
    @State private var isProUnlocked = ProEntitlementService.isUnlocked
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.iPadContentInset) private var hInset

    @MainActor
    init(viewModel: SettingsViewModel? = nil) {
        _viewModel = State(initialValue: viewModel ?? SettingsViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    compactHeader
                    premiumBanner
                    settingsSection("Preferences") { preferencesRows }
                    settingsSection("Notifications & Feedback") { feedbackRows }
                    settingsSection("Shortcuts") { shortcutRows }
                    settingsSection("Data") { dataRows }
                    settingsSection("About") { aboutRows }

                    #if DEBUG
                    settingsSection("Debug") { debugRows }
                    #endif
                }
                .padding(.horizontal, AppSpacing.lg + hInset)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, 96)
            }
            .background(AppColors.background(for: colorScheme))
            .navigationBarHidden(true)
        }
        .task {
            await viewModel.load(modelContainer: modelContext.container)
            viewModel.refreshStats(modelContext: modelContext)
            isProUnlocked = ProEntitlementService.isUnlocked
        }
        .onReceive(NotificationCenter.default.publisher(for: .delaydProEntitlementChanged)) { note in
            if let unlocked = note.object as? Bool {
                isProUnlocked = unlocked
            } else {
                isProUnlocked = ProEntitlementService.isUnlocked
            }
        }
        .fullScreenCover(isPresented: $isProSheetPresented) {
            DelaydProView(
                onClose: { isProSheetPresented = false },
                onSubscribe: { _ in
                    isProSheetPresented = false
                },
                onRestore: {
                    isProSheetPresented = false
                },
                onManageSubscription: {
                    isProSheetPresented = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(260))
                        isCustomerCenterPresented = true
                    }
                }
            )
        }
        .sheet(isPresented: $isThemePickerPresented) {
            ThemePickerSheet(
                selectedTheme: viewModel.appTheme,
                onSelect: { option in
                    viewModel.updateTheme(option)
                    isThemePickerPresented = false
                }
            )
            .delaydPageSheet(detents: [.height(360)])
        }
        .sheet(isPresented: $isTonePickerPresented) {
            TonePickerSheet(
                selectedTone: viewModel.tone,
                onSelect: { option in
                    viewModel.updateTone(option)
                    isTonePickerPresented = false
                }
            )
            .delaydPageSheet(detents: [.large])
        }
        .sheet(item: $activeSettingsSheet) { sheet in
            settingsUtilitySheet(sheet)
        }
        .sheet(isPresented: $isCreateGoalPresented) {
            CreateGoalSheet(
                onClose: {
                    isCreateGoalPresented = false
                },
                onCreate: { goal in
                    Task {
                        let goalRepository = GoalRepository(modelContainer: modelContext.container)
                        let activeGoals = await goalRepository.fetchActive()
                        guard ProEntitlementService.isUnlocked || activeGoals.isEmpty else {
                            isCreateGoalPresented = false
                            isProSheetPresented = true
                            return
                        }
                        let created = await goalRepository.create(
                            name: goal.name,
                            emoji: goal.category.emoji,
                            category: goal.category,
                            targetAmount: goal.targetAmount,
                            deadline: goal.daysRemaining > 0
                                ? Calendar.current.date(byAdding: .day, value: goal.daysRemaining, to: .now)
                                : nil
                        )
                        viewModel.updateDefaultGoal(id: created.id)
                        await viewModel.load(modelContainer: modelContext.container)
                        isCreateGoalPresented = false
                    }
                }
            )
            .delaydPageSheet(detents: [.large])
        }
        .sheet(isPresented: $isCustomerCenterPresented) {
            CustomerCenterView()
                .onCustomerCenterRestoreCompleted { customerInfo in
                    _ = ProEntitlementService.isProActive(customerInfo)
                    Task {
                        await ProEntitlementService.refreshCustomerInfo()
                    }
                }
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Settings")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            Text("Keep Delayd tuned to how you protect your goals.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            Text("No login. Local-first data on this device.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary(for: colorScheme))
        }
    }

    private var premiumBanner: some View {
        Button {
            isProSheetPresented = true
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack(alignment: .bottomTrailing) {
                    Image("PaywallHero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

                    if isProUnlocked {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(AppColors.positive, in: Circle())
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(isProUnlocked ? "Delayd Pro Active" : "Delayd Pro")
                        .font(AppTypography.bodyMedium)

                    Text(isProUnlocked ? "Premium features unlocked" : "Unlock advanced insights")
                        .font(AppTypography.callout)
                        .opacity(0.78)
                }

                Spacer()

                if !isProUnlocked {
                    Image(systemName: "chevron.right")
                        .font(.callout.weight(.semibold))
                        .opacity(0.78)
                }
            }
            .delaydHeroCard()
            .overlay {
                BrandPatternLayer(strength: colorScheme == .dark ? 0.45 : 0.62)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
    }

    private var preferencesRows: some View {
        VStack(spacing: 0) {
            Button {
                activeSettingsSheet = .currency
            } label: {
                row(systemImage: "dollarsign.circle.fill", title: "Currency", value: viewModel.selectedCurrency)
            }
            .buttonStyle(.plain)
            divider
            Button {
                activeSettingsSheet = .monthlySavings
            } label: {
                row(systemImage: "target", title: "Monthly Savings Target", value: viewModel.monthlySavingsText)
            }
            .buttonStyle(.plain)
            divider
            Button {
                activeSettingsSheet = .defaultGoal
            } label: {
                row(systemImage: "star.circle.fill", title: "Default Goal", value: viewModel.defaultGoalName)
            }
            .buttonStyle(.plain)
            divider
            Button {
                isThemePickerPresented = true
            } label: {
                row(systemImage: "paintbrush.fill", title: "Appearance", value: viewModel.appTheme.title)
            }
            .buttonStyle(.plain)
            divider
            Button {
                isTonePickerPresented = true
            } label: {
                row(systemImage: "text.bubble.fill", title: "Tone of Voice", value: "\(viewModel.tone.emoji) \(viewModel.tone.title)")
            }
            .buttonStyle(.plain)
        }
    }

    private var feedbackRows: some View {
        VStack(spacing: 0) {
            toggleRow(
                systemImage: "bell.badge.fill",
                title: "Notifications",
                subtitle: "Daily reminder to log your expenses",
                isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { newValue in
                        Task {
                            await viewModel.updateNotifications(enabled: newValue)
                            // If the toggle flipped on but came back off, the
                            // system denied the request — surface the alert.
                            if newValue && !viewModel.notificationsEnabled {
                                isNotificationDeniedAlertPresented = true
                            }
                        }
                    }
                )
            )
            divider
            toggleRow(
                systemImage: "clock.badge.fill",
                title: "Daily Delay Summary",
                subtitle: "One evening recap of what moved your dreams",
                isOn: Binding(
                    get: { viewModel.dailyDelaySummaryEnabled },
                    set: { viewModel.updateDailyDelaySummary(enabled: $0) }
                ),
                isDisabled: !viewModel.notificationsEnabled
            )
            divider
            toggleRow(
                systemImage: "sparkles",
                title: "Smart Delay Reminders",
                subtitle: "Rule-based nudges when your weekly trend worsens",
                isOn: Binding(
                    get: { viewModel.smartDelayRemindersEnabled },
                    set: { viewModel.updateSmartDelayReminders(enabled: $0) }
                ),
                isDisabled: !viewModel.notificationsEnabled,
                isProLocked: !isProUnlocked
            )
            .onTapGesture {
                if !isProUnlocked {
                    isProSheetPresented = true
                }
            }
            divider
            toggleRow(
                systemImage: "calendar.badge.clock",
                title: "Weekly Dream Recap",
                subtitle: "Sunday recap of protected money and delays",
                isOn: Binding(
                    get: { viewModel.weeklyDreamRecapEnabled },
                    set: { viewModel.updateWeeklyDreamRecap(enabled: $0) }
                ),
                isDisabled: !viewModel.notificationsEnabled,
                isProLocked: !isProUnlocked
            )
            .onTapGesture {
                if !isProUnlocked {
                    isProSheetPresented = true
                }
            }
            divider
            Button {
                if isProUnlocked {
                    activeSettingsSheet = .notificationTimes
                } else {
                    isProSheetPresented = true
                }
            } label: {
                row(
                    systemImage: "clock.arrow.circlepath",
                    title: "Notification Times",
                    value: viewModel.dailyReminderTimeText,
                    isProLocked: !isProUnlocked
                )
            }
            .buttonStyle(.plain)
            divider
            toggleRow(
                systemImage: "waveform.path",
                title: "Haptics",
                subtitle: "Feel the impact",
                isOn: Binding(
                    get: { viewModel.hapticsEnabled },
                    set: { viewModel.updateHaptics(enabled: $0) }
                )
            )
        }
        .alert("Notifications Blocked", isPresented: $isNotificationDeniedAlertPresented) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("To receive delay reminders, enable notifications for Delayd in iOS Settings.")
        }
    }

    private var dataRows: some View {
        VStack(spacing: 0) {
            Button {
                if isProUnlocked {
                    activeSettingsSheet = .exportData
                } else {
                    isProSheetPresented = true
                }
            } label: {
                row(systemImage: "square.and.arrow.up", title: "Export Data", value: "Local file", isProLocked: !isProUnlocked)
            }
            .buttonStyle(.plain)
            divider
            Button {
                activeSettingsSheet = .sync
            } label: {
                row(systemImage: "icloud.fill", title: "Sync to Cloud", value: "V1.1")
            }
            .buttonStyle(.plain)
        }
    }

    private var shortcutRows: some View {
        VStack(spacing: 0) {
            Button {
                activeSettingsSheet = .quickCapture
            } label: {
                row(systemImage: "hand.tap.fill", title: "Quick Capture Setup", value: "Back Tap")
            }
            .buttonStyle(.plain)
        }
    }

    private var aboutRows: some View {
        VStack(spacing: 0) {
            Button {
                activeSettingsSheet = .version
            } label: {
                row(systemImage: "number.circle.fill", title: "Version", value: "1.0")
            }
            .buttonStyle(.plain)
            divider
            Button {
                activeSettingsSheet = .privacy
            } label: {
                row(systemImage: "hand.raised.fill", title: "Privacy Policy", value: nil)
            }
            .buttonStyle(.plain)
            divider
            Button {
                activeSettingsSheet = .terms
            } label: {
                row(systemImage: "doc.text.fill", title: "Terms", value: nil)
            }
            .buttonStyle(.plain)
            divider
            Button {
                requestAppStoreReview()
            } label: {
                row(systemImage: "heart.fill", title: "Rate App", value: nil)
            }
            .buttonStyle(.plain)
            divider
            Button {
                isCustomerCenterPresented = true
            } label: {
                row(systemImage: "person.crop.circle.badge.checkmark", title: "Manage Subscription", value: "RevenueCat")
            }
            .buttonStyle(.plain)
        }
    }

    #if DEBUG
    private var debugRows: some View {
        VStack(spacing: 0) {
            Button {
                viewModel.wipeAllData(modelContext: modelContext)
            } label: {
                rowContent(systemImage: "trash.fill", title: "Wipe All Data", value: nil, tint: AppColors.negative)
            }
            .buttonStyle(.plain)

            divider

            Button {
                viewModel.reseedDemoData(modelContext: modelContext)
            } label: {
                rowContent(systemImage: "arrow.clockwise.circle.fill", title: "Reseed Demo Data", value: nil, tint: AppColors.purplePrimary)
            }
            .buttonStyle(.plain)

            divider

            row(systemImage: "externaldrive.fill", title: "Database Stats", value: viewModel.databaseStatsText)
        }
    }
    #endif

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.system(.subheadline, design: .default, weight: .bold))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .padding(.horizontal, AppSpacing.xs)

            content()
                .delaydCard()
        }
    }

    private func row(systemImage: String, title: String, value: String?, isProLocked: Bool = false) -> some View {
        rowContent(systemImage: systemImage, title: title, value: value, tint: AppColors.purplePrimary, isProLocked: isProLocked)
    }

    private func rowContent(
        systemImage: String,
        title: String,
        value: String?,
        tint: Color,
        isProLocked: Bool = false
    ) -> some View {
        let palette = settingsIconPalette(systemImage: systemImage, fallback: tint)

        return HStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.tint)
                .frame(width: 34, height: 34)
                .background(palette.background.opacity(colorScheme == .dark ? 0.18 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))

            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            Spacer(minLength: AppSpacing.sm)

            if let value {
                Text(value)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            if isProLocked {
                Text("PRO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppColors.purplePrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1),
                        in: Capsule()
                    )
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary(for: colorScheme))
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private func toggleRow(
        systemImage: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        isDisabled: Bool = false,
        isProLocked: Bool = false
    ) -> some View {
        let palette = settingsIconPalette(systemImage: systemImage, fallback: AppColors.purplePrimary, isDisabled: isDisabled)

        return HStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.tint)
                .frame(width: 34, height: 34)
                .background(palette.background.opacity(colorScheme == .dark ? 0.18 : (isDisabled ? 0.5 : 1)), in: RoundedRectangle(cornerRadius: AppRadius.md))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                Text(subtitle)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            Spacer(minLength: AppSpacing.sm)

            if isProLocked {
                Text("PRO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppColors.purplePrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1),
                        in: Capsule()
                    )
            } else {
                Toggle(title, isOn: isOn)
                    .labelsHidden()
                    .tint(AppColors.purplePrimary)
                    .disabled(isDisabled)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .opacity((isDisabled && !isProLocked) ? 0.58 : 1)
    }

    private func settingsIconPalette(
        systemImage: String,
        fallback: Color,
        isDisabled: Bool = false
    ) -> (tint: Color, background: Color) {
        guard !isDisabled else {
            return (AppColors.textTertiary(for: colorScheme), AppColors.softSurface(for: colorScheme))
        }

        if systemImage.contains("dollarsign") || systemImage.contains("text.bubble") || systemImage.contains("arrow.clockwise") {
            return (AppColors.purplePrimary, AppColors.softPurpleBackground)
        }
        if systemImage.contains("target") || systemImage.contains("hand.tap") || systemImage.contains("number") {
            return (AppColors.warning, AppColors.softWarningBackground)
        }
        if systemImage.contains("star") || systemImage.contains("bell") || systemImage.contains("heart") {
            return (AppColors.positive, AppColors.softPositiveBackground)
        }
        if systemImage.contains("paintbrush") || systemImage.contains("trash") {
            return (AppColors.negative, AppColors.softNegativeBackground)
        }
        if systemImage.contains("icloud") || systemImage.contains("square.and.arrow") || systemImage.contains("clock") || systemImage.contains("doc") {
            return (AppColors.vehicleAccent, AppColors.vehicleBackground)
        }
        if systemImage.contains("waveform") || systemImage.contains("hand.raised") || systemImage.contains("externaldrive") {
            return (AppColors.homeAccent, AppColors.homeBackground)
        }

        return (fallback, AppColors.softPurpleBackground)
    }

    private var divider: some View {
        Divider()
            .overlay(AppColors.border(for: colorScheme))
    }

    /// Triggers the in-app App Store review prompt via `SKStoreReviewController`.
    /// Apple rate-limits this to ~3 prompts per year per user, and silently
    /// no-ops in TestFlight builds — but it never fails or crashes, so we
    /// simply call it and rely on the system to do the right thing.
    private func requestAppStoreReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return
        }
        SKStoreReviewController.requestReview(in: scene)
    }

    @ViewBuilder
    private func settingsUtilitySheet(_ sheet: SettingsUtilitySheet) -> some View {
        switch sheet {
        case .currency:
            CurrencyPickerSheet(
                selectedCurrency: viewModel.selectedCurrency,
                onSelect: { currency in
                    viewModel.updateCurrency(currency)
                    activeSettingsSheet = nil
                }
            )
            .delaydPageSheet(detents: [.large])
        case .monthlySavings:
            MonthlySavingsTargetSheet(
                currentTarget: viewModel.monthlySavingsTarget,
                currencyCode: viewModel.selectedCurrency,
                onSave: { amount in
                    viewModel.updateMonthlySavingsTarget(amount)
                    activeSettingsSheet = nil
                }
            )
            .delaydPageSheet(detents: [.height(540), .medium])
        case .defaultGoal:
            GoalSwitcherSheet(
                title: "Default Goal",
                subtitle: "Pick the dream new expenses attach to first.",
                selectedGoalId: viewModel.defaultGoalId,
                onSelect: { goalId in
                    viewModel.updateDefaultGoal(id: goalId)
                    activeSettingsSheet = nil
                },
                onCreateNew: {
                    activeSettingsSheet = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(260))
                        let goalRepository = GoalRepository(modelContainer: modelContext.container)
                        let activeGoals = await goalRepository.fetchActive()
                        guard ProEntitlementService.isUnlocked || activeGoals.isEmpty else {
                            isProSheetPresented = true
                            return
                        }
                        isCreateGoalPresented = true
                    }
                }
            )
            .delaydPageSheet(detents: [.height(490), .medium])
        case .quickCapture:
            QuickCaptureSetupSheet(onDone: { activeSettingsSheet = nil })
                .delaydPageSheet(detents: [.large])
        case .exportData:
            ExportDataSheet(onDone: { activeSettingsSheet = nil })
                .delaydPageSheet(detents: [.height(360)])
        case .sync:
            SettingsInfoSheet(
                systemImage: "icloud.fill",
                title: "Cloud Sync",
                subtitle: "Sync is planned for V1.1, while V1 stays local-first.",
                detail: "This keeps launch simpler: no account creation, no forced sign-in, and no cloud dependency before the core habit loop is proven.",
                primaryTitle: "Got it",
                onPrimary: { activeSettingsSheet = nil }
            )
            .delaydPageSheet(detents: [.height(410), .medium])
        case .version:
            SettingsInfoSheet(
                systemImage: "number.circle.fill",
                title: "Delayd 1.0",
                subtitle: "Local-first V1 build.",
                detail: "Current scope: goals, manual expense logging, delay reveals, smart insights, light/dark mode, and local SwiftData storage.",
                primaryTitle: "Done",
                onPrimary: { activeSettingsSheet = nil }
            )
            .delaydPageSheet(detents: [.height(390), .medium])
        case .privacy:
            LegalDocumentSheet(
                systemImage: "hand.raised.fill",
                title: "Privacy Policy",
                subtitle: "Delayd is local-first. Your data stays on your device.",
                sourceURL: URL(string: "https://www.droidates.com/p/privacy-policy-delayd.html")!,
                sections: [
                    LegalSection(title: "Local-first data", body: "Goals, logged expenses, protected amounts, settings, and delay impacts are stored on this device using SwiftData. Delayd does not require an account or sign-in for V1."),
                    LegalSection(title: "No bank access", body: "Delayd does not connect to banks, payment accounts, cards, salary data, or financial institutions. All expense entries are created manually by you."),
                    LegalSection(title: "Permissions", body: "Notifications are optional and are used only for local reminders and delay recaps. Haptics stay on-device. Delayd does not request contacts, location, photos, microphone, camera, or tracking permission for V1."),
                    LegalSection(title: "Purchases", body: "If you buy Delayd Pro, Apple and RevenueCat process purchase status so the app can unlock premium features. Your dream and expense data remains local to your device."),
                    LegalSection(title: "Future sync", body: "If cloud sync ships later, it will be opt-in and explained before any data leaves your device. Uninstalling the V1 app removes local app data from the device.")
                ],
                onClose: { activeSettingsSheet = nil }
            )
            .delaydPageSheet(detents: [.large])
        case .terms:
            LegalDocumentSheet(
                systemImage: "doc.text.fill",
                title: "Terms of Use",
                subtitle: "By using Delayd, you agree to these terms.",
                sourceURL: URL(string: "https://www.droidates.com/p/terms-of-use-delayd.html")!,
                sections: [
                    LegalSection(title: "Personal awareness tool", body: "Delayd is provided for personal financial awareness. It is not a bank, licensed financial advisor, investment advisor, credit product, accounting product, or budgeting service."),
                    LegalSection(title: "Estimated delay impact", body: "Delay calculations are estimates based on the monthly savings target and expenses you enter. They are not guarantees of savings, investment performance, goal completion, or financial outcomes."),
                    LegalSection(title: "Your entries", body: "You are responsible for the accuracy of goals, targets, protected amounts, and expenses you log. Delayd does not verify purchases or access external financial accounts."),
                    LegalSection(title: "Delayd Pro", body: "Pro unlocks local premium features described in the app. Subscriptions renew through your Apple ID until cancelled. Lifetime purchases do not renew."),
                    LegalSection(title: "Local storage", body: "V1 stores data on your device. Removing the app can permanently remove local data unless you have a device backup that includes it.")
                ],
                onClose: { activeSettingsSheet = nil }
            )
            .delaydPageSheet(detents: [.large])
        case .notificationTimes:
            NotificationTimesSheet(
                dailyTime: viewModel.dailyReminderTime,
                smartTime: viewModel.smartReminderTime,
                weeklyTime: viewModel.weeklyRecapTime,
                onSave: { daily, smart, weekly in
                    viewModel.updateDailyReminderTime(daily)
                    viewModel.updateSmartReminderTime(smart)
                    viewModel.updateWeeklyRecapTime(weekly)
                    activeSettingsSheet = nil
                }
            )
            .delaydPageSheet(detents: [.height(430), .large])
        }
    }
}

private enum SettingsUtilitySheet: String, Identifiable {
    case currency
    case monthlySavings
    case defaultGoal
    case quickCapture
    case exportData
    case sync
    case version
    case privacy
    case terms
    case notificationTimes

    var id: String { rawValue }
}

private struct NotificationTimesSheet: View {
    @State private var dailyDate: Date
    @State private var smartDate: Date
    @State private var weeklyDate: Date
    let onSave: (DateComponents, DateComponents, DateComponents) -> Void
    @Environment(\.colorScheme) private var colorScheme

    init(
        dailyTime: DateComponents,
        smartTime: DateComponents,
        weeklyTime: DateComponents,
        onSave: @escaping (DateComponents, DateComponents, DateComponents) -> Void
    ) {
        _dailyDate = State(initialValue: Self.date(from: dailyTime, fallbackHour: 20, fallbackMinute: 0))
        _smartDate = State(initialValue: Self.date(from: smartTime, fallbackHour: 17, fallbackMinute: 30))
        _weeklyDate = State(initialValue: Self.date(from: weeklyTime, fallbackHour: 18, fallbackMinute: 0))
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SettingsSheetHeader(
                systemImage: "clock.arrow.circlepath",
                title: "Notification Times",
                subtitle: "Pro: choose when reminders should arrive."
            )
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)

            VStack(spacing: AppSpacing.sm) {
                timeRow(title: "Daily Reminder", date: $dailyDate)
                timeRow(title: "Smart Delay Reminder", date: $smartDate)
                timeRow(title: "Weekly Recap (Sunday)", date: $weeklyDate)
            }
            .padding(.horizontal, AppSpacing.lg)

            Spacer(minLength: AppSpacing.md)

            PrimaryButton("Save Times") {
                onSave(
                    Self.components(from: dailyDate),
                    Self.components(from: smartDate),
                    Self.components(from: weeklyDate)
                )
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    private func timeRow(title: String, date: Binding<Date>) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "clock.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.purplePrimary)
                .frame(width: 36, height: 36)
                .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))

            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: AppSpacing.sm)

            DatePicker(title, selection: date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(AppColors.purplePrimary)
        }
        .padding(AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private static func components(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: date)
    }

    private static func date(from components: DateComponents, fallbackHour: Int, fallbackMinute: Int) -> Date {
        let hour = components.hour ?? fallbackHour
        let minute = components.minute ?? fallbackMinute
        return Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }
}

private struct CurrencyPickerSheet: View {
    let selectedCurrency: String
    let onSelect: (String) -> Void

    @State private var searchText = ""
    @Environment(\.colorScheme) private var colorScheme

    private var detectedCurrency: String {
        CurrencyFormatter.localeDefaultCurrencyCode
    }

    private var filteredOptions: [CurrencyOption] {
        CurrencyFormatter.allCurrencyOptions.filter { $0.matches(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SettingsSheetHeader(
                        systemImage: "dollarsign.circle.fill",
                        title: "Currency",
                        subtitle: "Delayd can default to your iPhone region, then you can override it here."
                    )

                    if let detected = CurrencyFormatter.allCurrencyOptions.first(where: { $0.code == detectedCurrency }) {
                        Button {
                            onSelect(detected.code)
                        } label: {
                            HStack(spacing: AppSpacing.md) {
                                Image(systemName: "location.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppColors.purplePrimary)
                                    .frame(width: 38, height: 38)
                                    .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Detected from iPhone region")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                    Text("\(detected.symbol) \(detected.code) · \(detected.name)")
                                        .font(AppTypography.bodyMedium)
                                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }

                                Spacer()
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.lg)
                                    .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)

                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(filteredOptions) { option in
                            selectableRow(
                                leading: option.symbol,
                                title: option.code,
                                subtitle: option.name,
                                isSelected: selectedCurrency == option.code
                            ) {
                                onSelect(option.code)
                            }
                        }

                        Text("V1 uses one app-wide currency. Per-goal currencies are intentionally not part of V1.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, AppSpacing.sm)
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .background(AppColors.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search currency")
        }
    }

    private func selectableRow(
        leading: String,
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: AppSpacing.md) {
            Text(leading)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.purplePrimary)
                .frame(width: 42, height: 42)
                .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.purplePrimary)
            }
        }
        .settingsSelectionCard(isSelected: isSelected, colorScheme: colorScheme)
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct MonthlySavingsTargetSheet: View {
    let currentTarget: Double
    let onSave: (Double) -> Void
    var currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode

    @State private var targetText: String
    @FocusState private var isAmountFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let presets = [5_000, 10_000, 25_000, 50_000]

    init(currentTarget: Double, currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode, onSave: @escaping (Double) -> Void) {
        self.currentTarget = currentTarget
        self.currencyCode = currencyCode
        self.onSave = onSave
        _targetText = State(initialValue: Self.formatPlain(currentTarget))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsSheetHeader(
                    systemImage: "target",
                    title: "Monthly Savings Target",
                    subtitle: "This is the monthly pace Delayd uses to convert spending into delay days."
                )

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Target amount")
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                    HStack(spacing: AppSpacing.sm) {
                        Text(CurrencyFormatter.symbol(for: currencyCode))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.purplePrimary)

                        TextField("10000", text: $targetText)
                            .keyboardType(.numberPad)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                            .focused($isAmountFocused)
                            .onChange(of: targetText) { _, newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    targetText = filtered
                                }
                            }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                    }

                    if isAmountFocused {
                        Button("Done editing") {
                            isAmountFocused = false
                        }
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.purplePrimary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: Capsule())
                        .buttonStyle(.plain)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                    ForEach(presets, id: \.self) { amount in
                        Button {
                            targetText = "\(amount)"
                        } label: {
                            Text(CurrencyFormatter.format(Double(amount), currencyCode: currencyCode))
                                .font(.system(.callout, design: .default, weight: .medium))
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.md)
                                .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.md))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppRadius.md)
                                        .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                PrimaryButton("Save Target", systemImage: "checkmark") {
                    if let amount = parsedAmount, amount > 0 {
                        onSave(amount)
                    }
                }
                .disabled(parsedAmount == nil || parsedAmount == 0)
                .opacity(parsedAmount == nil || parsedAmount == 0 ? 0.5 : 1)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isAmountFocused = false
                }
                .font(.system(size: 15, weight: .semibold))
            }
        }
    }

    private var parsedAmount: Double? {
        Double(targetText.filter { $0.isNumber })
    }

    private static func formatPlain(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}

private struct DefaultGoalPickerSheet: View {
    let selectedGoalId: UUID?
    let onSelect: (UUID) -> Void

    @Query(filter: #Predicate<Goal> { !$0.isArchived },
           sort: \Goal.createdAt, order: .reverse)
    private var liveGoals: [Goal]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsSheetHeader(
                    systemImage: "star.circle.fill",
                    title: "Default Goal",
                    subtitle: "Pick the dream new expenses attach to first."
                )

                if liveGoals.isEmpty {
                    Text("No goals yet. Create a goal in the Plan tab first.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                        .padding(AppSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                        }
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(liveGoals) { goal in
                            Button {
                                onSelect(goal.id)
                            } label: {
                                HStack(spacing: AppSpacing.md) {
                                    GoalCategoryIcon(category: goal.category, size: 42)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(goal.name.delaydGoalTitleCased)
                                            .font(AppTypography.bodyMedium)
                                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                        Text(goal.category.label)
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                    }

                                    Spacer()

                                    if selectedGoalId == goal.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(AppColors.purplePrimary)
                                    }
                                }
                                .settingsSelectionCard(isSelected: selectedGoalId == goal.id, colorScheme: colorScheme)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }
}

private struct SettingsInfoSheet: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let detail: String
    let primaryTitle: String
    let onPrimary: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsSheetHeader(systemImage: systemImage, title: title, subtitle: subtitle)

                Text(detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppSpacing.md)
                    .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                    }

                PrimaryButton(primaryTitle, action: onPrimary)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }
}

private struct LegalSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

private struct LegalDocumentSheet: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let sourceURL: URL
    let sections: [LegalSection]
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SettingsSheetHeader(systemImage: systemImage, title: title, subtitle: subtitle)

                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(section.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                                Text(section.body)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(AppSpacing.lg)
                    .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.xl))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.xl)
                            .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                    }

                    Link(destination: sourceURL) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "arrow.up.right.square.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Open full document")
                                .font(AppTypography.bodyMedium)
                            Spacer()
                        }
                        .foregroundStyle(AppColors.purplePrimary)
                        .padding(AppSpacing.md)
                        .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                    }

                    PrimaryButton("Done", action: onClose)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.background(for: colorScheme).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}

private struct QuickCaptureSetupSheet: View {
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    private let steps: [QuickCaptureStep] = [
        QuickCaptureStep(
            number: "1",
            icon: "shortcuts",
            title: "Create the shortcut",
            detail: "Open Shortcuts, add Delayd Log Expense, then set Amount, Spend Type, Custom Merchant, and Date to Ask Each Time.",
            action: .openShortcuts
        ),
        QuickCaptureStep(
            number: "2",
            icon: "hand.tap.fill",
            title: "Assign Back Tap",
            detail: "Open iPhone Settings, go to Accessibility, Touch, Back Tap, Double Tap, then choose your Delayd Log Expense shortcut.",
            action: .openSettings
        ),
        QuickCaptureStep(
            number: "3",
            icon: "iphone.gen3",
            title: "Log from anywhere",
            detail: "Double tap the back of your iPhone. iOS asks for the amount, spend type, merchant, date, then shows a confirmation before saving the delay impact."
        )
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsSheetHeader(
                    systemImage: "bolt.badge.clock.fill",
                    title: "Quick Capture",
                    subtitle: "Use iOS Shortcuts and Back Tap to log a spend without opening Delayd first."
                )

                previewCard

                VStack(spacing: AppSpacing.sm) {
                    ForEach(steps) { step in
                        stepRow(step)
                    }
                }

                Text("Quick Capture saves the expense immediately and returns the delay result in the Shortcuts prompt. Use Open Quick Log when you want the full in-app reveal animation.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Text("iOS does not provide an App Store-safe link directly to Accessibility > Touch > Back Tap, so Settings may still need manual navigation from there.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryButton("Done", action: onDone)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    private func setupActionLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(AppTypography.bodyMedium)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(AppColors.purplePrimary)
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.purplePrimary)
                Text("Shortcut prompt")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("What is the amount?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                Text("500")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.softSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))

                HStack(spacing: AppSpacing.sm) {
                    shortcutChip("Coffee")
                    shortcutChip("Food")
                    shortcutChip("Other")
                }

                Text("Confirm: $500 • Coffee • Bali Trip • 2 days")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.negative)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private func shortcutChip(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.captionMedium)
            .foregroundStyle(AppColors.purplePrimary)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: Capsule())
    }

    private func stepRow(_ step: QuickCaptureStep) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1))
                Text(step.number)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.purplePrimary)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Label(step.title, systemImage: step.icon)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                Text(step.detail)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                if let action = step.action {
                    Button {
                        switch action {
                        case .openShortcuts:
                            if let url = URL(string: "shortcuts://") {
                                openURL(url)
                            }
                        case .openSettings:
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        }
                    } label: {
                        setupActionLabel(title: action.buttonTitle, systemImage: action.systemImage)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, AppSpacing.sm)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }
}

private struct QuickCaptureStep: Identifiable {
    let id = UUID()
    let number: String
    let icon: String
    let title: String
    let detail: String
    var action: QuickCaptureStepAction?
}

private enum QuickCaptureStepAction {
    case openShortcuts
    case openSettings

    var buttonTitle: String {
        switch self {
        case .openShortcuts:
            return "Open Shortcuts"
        case .openSettings:
            return "Open Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .openShortcuts:
            return "shortcuts"
        case .openSettings:
            return "gearshape.fill"
        }
    }
}

private struct SettingsSheetHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.purplePrimary)
                .frame(width: 46, height: 46)
                .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GoalOption: Identifiable {
    let name: String
    let emoji: String
    let category: String

    var id: String { name }
}

private extension View {
    func settingsSelectionCard(isSelected: Bool, colorScheme: ColorScheme) -> some View {
        self
            .padding(AppSpacing.md)
            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(
                        isSelected ? AppColors.purplePrimary.opacity(0.72) : AppColors.border(for: colorScheme),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
    }
}

// MARK: - Export Data Sheet

private struct ExportDataSheet: View {
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var isSharePresented = false
    @State private var exportURL: URL?
    @State private var isExporting = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsSheetHeader(
                    systemImage: "square.and.arrow.up",
                    title: "Export Data",
                    subtitle: "Export your goals and delay impacts as a JSON file you can save or share."
                )

                Text("Your data stays local. The export creates a plain JSON file — no account or upload required.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppSpacing.md)
                    .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                    }

                PrimaryButton(isExporting ? "Preparing..." : "Export JSON", systemImage: "square.and.arrow.up") {
                    Task { await export() }
                }
                .disabled(isExporting)
                .opacity(isExporting ? 0.6 : 1)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
        .sheet(isPresented: $isSharePresented, onDismiss: onDone) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func export() async {
        isExporting = true
        defer { isExporting = false }

        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>())) ?? []
        let expenses = (try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []

        let iso = ISO8601DateFormatter()
        let goalsJSON: [[String: Any]] = goals.map { goal in
            var dict: [String: Any] = [
                "id": goal.id.uuidString,
                "name": goal.name,
                "category": goal.categoryRawValue,
                "targetAmount": goal.targetAmount,
                "currentAmount": goal.currentAmount,
                "createdAt": iso.string(from: goal.createdAt)
            ]
            if let deadline = goal.deadline { dict["deadline"] = iso.string(from: deadline) }
            return dict
        }

        let expensesJSON: [[String: Any]] = expenses.map { expense in
            var dict: [String: Any] = [
                "id": expense.id.uuidString,
                "amount": expense.amount,
                "occurredAt": iso.string(from: expense.occurredAt)
            ]
            if let merchant = expense.merchant { dict["merchant"] = merchant }
            if let tag = expense.tag { dict["tag"] = tag }
            if let note = expense.note { dict["note"] = note }
            if let goalId = expense.linkedGoal?.id { dict["linkedGoalId"] = goalId.uuidString }
            return dict
        }

        let payload: [String: Any] = [
            "exportedAt": iso.string(from: .now),
            "app": "Delayd",
            "version": "1.0",
            "goals": goalsJSON,
            "expenses": expensesJSON
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let tempURL = try? writeTemp(data: data) else { return }

        exportURL = tempURL
        isSharePresented = true
    }

    private func writeTemp(data: Data) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let name = "delayd-export-\(formatter.string(from: .now)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ThemePickerSheet: View {
    let selectedTheme: AppTheme
    let onSelect: (AppTheme) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsSheetHeader(
                    systemImage: "circle.lefthalf.filled",
                    title: "Appearance",
                    subtitle: "Choose how Delayd looks on this device."
                )

                VStack(spacing: AppSpacing.sm) {
                    ForEach(AppTheme.allCases) { option in
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: option.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppColors.purplePrimary)
                                .frame(width: 36, height: 36)
                                .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))

                            Text(option.title)
                                .font(AppTypography.bodyMedium)
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                            Spacer()

                            if option == selectedTheme {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppColors.purplePrimary)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .stroke(
                                    option == selectedTheme ? AppColors.purplePrimary.opacity(0.72) : AppColors.border(for: colorScheme),
                                    lineWidth: option == selectedTheme ? 2 : 1
                                )
                        }
                        .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .onTapGesture {
                            onSelect(option)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(option == selectedTheme ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }
}

private struct TonePickerSheet: View {
    let selectedTone: DelaydTone
    let onSelect: (DelaydTone) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                SettingsSheetHeader(
                    systemImage: "quote.bubble.fill",
                    title: "Tone of Voice",
                    subtitle: "Choose how Delayd speaks across nudges, insights, and reveals."
                )

                VStack(spacing: AppSpacing.sm) {
                    ForEach(DelaydTone.allCases) { tone in
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            Text(tone.emoji)
                                .font(.system(size: 24))
                                .frame(width: 42, height: 42)
                                .background(
                                    AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1),
                                    in: RoundedRectangle(cornerRadius: AppRadius.md)
                                )

                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(tone.title)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                                Text(tone.sampleLine)
                                    .font(AppTypography.callout)
                                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(tone.usageGuide)
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textTertiary(for: colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)

                            }

                            Spacer(minLength: AppSpacing.sm)

                            if tone == selectedTone {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(AppColors.purplePrimary)
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.lg)
                                .stroke(
                                    tone == selectedTone ? AppColors.purplePrimary.opacity(0.72) : AppColors.border(for: colorScheme),
                                    lineWidth: tone == selectedTone ? 2 : 1
                                )
                        }
                        .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                        .onTapGesture {
                            onSelect(tone)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(tone == selectedTone ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }
}

#Preview("Settings Light") {
    SettingsView(viewModel: .mock())
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Settings Dark") {
    SettingsView(viewModel: .mock())
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}

#Preview("Settings Edge") {
    SettingsView(viewModel: .mock())
        .modelContainer(PreviewContainer.shared)
        .dynamicTypeSize(.accessibility2)
        .preferredColorScheme(.light)
}

#Preview("Settings Currency Sheet") {
    CurrencyPickerSheet(selectedCurrency: "USD", onSelect: { _ in })
        .preferredColorScheme(.light)
}

#Preview("Settings Monthly Target Sheet") {
    MonthlySavingsTargetSheet(currentTarget: 10_000, onSave: { _ in })
        .preferredColorScheme(.light)
}

#Preview("Settings Info Sheet Dark") {
    SettingsInfoSheet(
        systemImage: "icloud.fill",
        title: "Cloud Sync",
        subtitle: "Sync is planned for V1.1, while V1 stays local-first.",
        detail: "This keeps launch simpler: no account creation, no forced sign-in, and no cloud dependency before the core habit loop is proven.",
        primaryTitle: "Got it",
        onPrimary: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Quick Capture Setup") {
    QuickCaptureSetupSheet(onDone: {})
        .preferredColorScheme(.light)
}
