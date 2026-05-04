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
    @State private var isNotificationDeniedAlertPresented = false
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
        }
        .fullScreenCover(isPresented: $isProSheetPresented) {
            DelaydProView(
                onClose: { isProSheetPresented = false },
                onSubscribe: { _ in
                    isProSheetPresented = false
                },
                onRestore: {
                    isProSheetPresented = false
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
        }
    }

    private var premiumBanner: some View {
        Button {
            isProSheetPresented = true
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: AppRadius.md))

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Delayd Pro")
                        .font(AppTypography.bodyMedium)

                    Text("Unlock advanced insights")
                        .font(AppTypography.callout)
                        .opacity(0.78)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .opacity(0.78)
            }
            .delaydHeroCard()
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
                activeSettingsSheet = .exportData
            } label: {
                row(systemImage: "square.and.arrow.up", title: "Export Data", value: "Local file")
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

    private func row(systemImage: String, title: String, value: String?) -> some View {
        rowContent(systemImage: systemImage, title: title, value: value, tint: AppColors.purplePrimary)
    }

    private func rowContent(systemImage: String, title: String, value: String?, tint: Color) -> some View {
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

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary(for: colorScheme))
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private func toggleRow(systemImage: String, title: String, subtitle: String, isOn: Binding<Bool>, isDisabled: Bool = false) -> some View {
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

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(AppColors.purplePrimary)
                .disabled(isDisabled)
        }
        .padding(.vertical, AppSpacing.sm)
        .opacity(isDisabled ? 0.58 : 1)
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
            DefaultGoalPickerSheet(
                selectedGoalId: viewModel.defaultGoalId,
                onSelect: { goalId in
                    viewModel.updateDefaultGoal(id: goalId)
                    activeSettingsSheet = nil
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
            SettingsInfoSheet(
                systemImage: "hand.raised.fill",
                title: "Privacy Policy",
                subtitle: "Delayd is local-first. Your data stays on your device.",
                detail: "Delayd does not collect, transmit, or sell any personal data. All goals, logged expenses, and delay impacts are stored exclusively on your device using Apple's SwiftData framework.\n\nNo account is required. No sign-in is ever forced. There is no analytics SDK, no advertising identifier collection, and no third-party data sharing in V1.\n\nIf you choose to enable cloud sync in a future version, that will be opt-in and clearly explained before any data leaves your device. Until then, uninstalling the app removes all data permanently.\n\nDelayd does not track your location, contacts, or any data outside the app. The only permission requested is optional notifications — solely to remind you to log expenses.",
                primaryTitle: "Got it",
                onPrimary: { activeSettingsSheet = nil }
            )
            .delaydPageSheet(detents: [.medium, .large])
        case .terms:
            SettingsInfoSheet(
                systemImage: "doc.text.fill",
                title: "Terms of Use",
                subtitle: "By using Delayd, you agree to these terms.",
                detail: "Delayd is provided as-is for personal financial awareness only. It is not a licensed financial advisor, bank, or investment service. Delay calculations are estimates based on your monthly savings target and logged expenses — they are not guaranteed financial outcomes.\n\nYou are responsible for the accuracy of the data you log. Delayd does not access your bank accounts or financial institutions.\n\nAll data is stored locally on your device. You can wipe all data at any time from Settings → Debug → Wipe All Data.\n\nFull terms of service will be published on the App Store listing prior to public release.",
                primaryTitle: "Got it",
                onPrimary: { activeSettingsSheet = nil }
            )
            .delaydPageSheet(detents: [.medium, .large])
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

    var id: String { rawValue }
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
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isAmountFocused = false }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.purplePrimary)
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
                                    Text(goal.emoji)
                                        .font(.system(size: 20))
                                        .frame(width: 42, height: 42)
                                        .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))

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

private struct QuickCaptureSetupSheet: View {
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    private let steps: [QuickCaptureStep] = [
        QuickCaptureStep(
            number: "1",
            icon: "shortcuts",
            title: "Create the shortcut",
            detail: "Open Shortcuts, add Delayd Quick Capture, then set Amount, Spend Type, Custom Merchant, and Date to Ask Each Time."
        ),
        QuickCaptureStep(
            number: "2",
            icon: "hand.tap.fill",
            title: "Assign Back Tap",
            detail: "Open iPhone Settings, go to Accessibility, Touch, Back Tap, Double Tap, then choose your Delayd Quick Capture shortcut."
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

                setupActions

                PrimaryButton("Done", action: onDone)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    private var setupActions: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                if let url = URL(string: "shortcuts://") {
                    openURL(url)
                }
            } label: {
                setupActionLabel(title: "Open Shortcuts", systemImage: "shortcuts")
            }
            .buttonStyle(.plain)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                setupActionLabel(title: "Open Settings", systemImage: "gearshape.fill")
            }
            .buttonStyle(.plain)

            Text("iOS does not provide an App Store-safe link directly to Accessibility > Touch > Back Tap, so Settings may still need manual navigation from there.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
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

                                Text("\(ToneCopyLibrary.totalLineCount(for: tone) + ImpactRevealCopy.totalLineCount(for: tone)) saved lines across reveals, insights, and reminders")
                                    .font(AppTypography.captionMedium)
                                    .foregroundStyle(AppColors.purplePrimary)
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
