import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: DelaydTab = .home
    @State private var isQuickActionMenuPresented = false
    @State private var isQuickLogPresented = false
    @State private var isProtectDreamPresented = false
    @State private var isSavedHistoryPresented = false
    @State private var isRevealPresented = false
    @State private var isBoostRevealPresented = false
    @State private var isPostRevealProPromptPresented = false
    @State private var isOnboardingCompleted: Bool
    @State private var shouldPresentRevealAfterQuickLog = false
    @State private var shouldPresentBoostRevealAfterProtectDream = false
    @State private var pendingImpact: DelayImpact?
    @State private var pendingBoostImpact: DreamBoostImpact?
    @State private var homeRefreshToken = 0
    @State private var historyRefreshToken = 0
    @State private var homeViewModel = HomeViewModel()
    /// Amount pre-filled into the sheet when launched via QuickLogIntent
    /// (Shortcuts, Siri, back-tap). Reset the moment the sheet renders so
    /// subsequent manual opens don't stay pre-filled.
    @State private var intentPrefilledAmount: Double?
    // Bridge is @Observable; `@State` is the right holder for a reference type
    // under the new Observation framework.
    @State private var intentBridge = QuickLogIntentBridge.shared
    /// Holds the Darwin notification subscription that fires when
    /// `QuickCaptureExpenseIntent` writes a new expense from the Shortcuts
    /// process. Storing it in `@State` keeps it alive for the view lifetime.
    @State private var quickCaptureObserver: DarwinObserverToken?

    private let onboardingCompletionOverride: Bool?
    private let onboardingCompletionKey = "delayd.onboarding.completed"
    private let postRevealProPromptShownKey = "delayd.pro.postRevealPromptShown"

    init(onboardingCompleted: Bool? = nil) {
        onboardingCompletionOverride = onboardingCompleted
        // Read onboarding flag synchronously so the first rendered frame IS the
        // real UI. The OS launch screen (UILaunchScreen in Info.plist — logo on
        // LaunchBackground, light/dark variants) stays on-screen until this
        // frame renders, so there is no second "SwiftUI splash" in between.
        _isOnboardingCompleted = State(
            initialValue: onboardingCompleted ?? UserDefaults.standard.bool(forKey: "delayd.onboarding.completed")
        )
    }

    var body: some View {
        rootContent
            .task {
                // Do setup work AFTER the real UI is already on-screen. No
                // artificial delay, no splash view — the native launch screen
                // already covered the cold-start window.
                //
                // CRITICAL: only seed demo data when the user has already
                // finished onboarding AND we explicitly want demo content for
                // DEBUG builds. Real first launches must hit empty SwiftData so
                // onboarding can write the user's real goal without colliding
                // with a fake "Bali trip" + 8 fake expenses.
                #if DEBUG
                if isOnboardingCompleted {
                    SeedDataService.seedIfNeeded(modelContext: modelContext)
                }
                #endif

                if let onboardingCompletionOverride {
                    isOnboardingCompleted = onboardingCompletionOverride
                    return
                }

                // Reconcile with persisted settings in case the UserDefaults
                // flag ever drifted from the SwiftData record. If they disagree
                // we correct in place; the UI updates silently without showing
                // a loading state.
                let settings = await SettingsRepository(modelContainer: modelContext.container).fetchSnapshot()
                let reconciled = UserDefaults.standard.bool(forKey: onboardingCompletionKey) && settings.onboardingCompleted
                if reconciled != isOnboardingCompleted {
                    isOnboardingCompleted = reconciled
                }

            }
            .onChange(of: intentBridge.requestToken) { _, _ in
                // A Shortcut/Siri/back-tap triggered QuickLogIntent. Consume
                // the pending amount, pre-fill the sheet, and present it.
                // Guard on onboarding because logging before setup is
                // meaningless — in that case just bring the app forward and
                // let onboarding finish.
                guard isOnboardingCompleted else { return }
                intentPrefilledAmount = intentBridge.consume()
                if !isQuickLogPresented {
                    isQuickLogPresented = true
                }
            }
            .onAppear {
                // Subscribe to Darwin notifications fired by
                // `QuickCaptureExpenseIntent.perform` when it writes an
                // expense from the Shortcuts process. We bump both refresh
                // tokens so HomeView and HistoryView re-query SwiftData
                // immediately when the user returns to the app, instead of
                // showing stale cards until they switch tabs.
                if quickCaptureObserver == nil {
                    quickCaptureObserver = QuickCaptureBroadcast.observeDidLogExpense {
                        homeRefreshToken &+= 1
                        historyRefreshToken &+= 1
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: QuickCaptureBroadcast.foundationName)) { _ in
                // Same-process fallback (intent ran inside the app).
                homeRefreshToken &+= 1
                historyRefreshToken &+= 1
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Belt-and-braces: even if the Darwin notification was
                // missed (e.g. fired while app was suspended and dropped),
                // refreshing on foreground guarantees fresh cards after any
                // background data change. Cheap — re-runs the same query
                // HomeView already runs at launch.
                homeRefreshToken &+= 1
                historyRefreshToken &+= 1
            }
            .onOpenURL { url in
                guard isOnboardingCompleted else { return }
                guard url.scheme == "delayd" else { return }

                switch url.host?.lowercased() {
                case "quicklog":
                    isQuickLogPresented = true
                case "history":
                    selectedTab = .history
                default:
                    break
                }
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        ZStack(alignment: .bottom) {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            if isOnboardingCompleted {
                appShell
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.015)),
                            removal: .opacity
                        )
                    )
                    .zIndex(2)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.42)) {
                        isOnboardingCompleted = true
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.025)))
                .zIndex(1)
            }

            if isRevealPresented, let pendingImpact {
                DelayedImpactRevealView(
                    impact: pendingImpact,
                    onDismiss: {
                        dismissReveal(shouldOfferProPrompt: true)
                    },
                    onUndo: {
                        undoPendingImpactAndDismiss()
                    }
                )
                .id(pendingImpact.expenseId ?? pendingImpact.affectedGoal.id)
                .zIndex(100)
                .transition(.opacity)
            }

            if isBoostRevealPresented, let pendingBoostImpact {
                DreamBoostRevealView(
                    impact: pendingBoostImpact,
                    onDismiss: dismissBoostReveal
                )
                .zIndex(101)
                .transition(.opacity)
            }

            if isQuickActionMenuPresented && isOnboardingCompleted {
                quickActionBackdrop
                    .zIndex(90)
                    .transition(.opacity)

                QuickActionMenu(
                    onLogSpend: {
                        withAnimation(AppMotion.sheetPresentation) {
                            isQuickActionMenuPresented = false
                        }
                        isQuickLogPresented = true
                    },
                    onProtectDream: {
                        withAnimation(AppMotion.sheetPresentation) {
                            isQuickActionMenuPresented = false
                        }
                        isProtectDreamPresented = true
                    }
                )
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, 84)
                .zIndex(91)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

        }
        .sheet(
            isPresented: $isQuickLogPresented,
            onDismiss: {
                guard shouldPresentRevealAfterQuickLog else { return }
                shouldPresentRevealAfterQuickLog = false

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(320))
                    if pendingImpact != nil {
                        withAnimation(.easeOut(duration: 0.18)) {
                            isRevealPresented = true
                        }
                    }
                }
            }
        ) {
            QuickLogSheet(
                viewModel: quickLogViewModelForPresentation(),
                onClose: {
                    isQuickLogPresented = false
                },
                onLogged: { impact in
                    pendingImpact = impact
                    homeRefreshToken += 1
                    historyRefreshToken += 1
                    shouldPresentRevealAfterQuickLog = true
                    isQuickLogPresented = false
                }
            )
            .onAppear { clearIntentPrefill() }
            .delaydPageSheet(detents: [.large])
        }
        .sheet(
            isPresented: $isSavedHistoryPresented,
            onDismiss: {
                homeRefreshToken &+= 1
            }
        ) {
            SavedHistorySheet(
                onClose: { isSavedHistoryPresented = false },
                onAddProtection: {
                    isSavedHistoryPresented = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(220))
                        isProtectDreamPresented = true
                    }
                }
            )
            .delaydPageSheet(detents: [.large])
        }
        .sheet(
            isPresented: $isProtectDreamPresented,
            onDismiss: {
                guard shouldPresentBoostRevealAfterProtectDream else { return }
                shouldPresentBoostRevealAfterProtectDream = false

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(320))
                    if pendingBoostImpact != nil {
                        withAnimation(.easeOut(duration: 0.18)) {
                            isBoostRevealPresented = true
                        }
                    }
                }
            }
        ) {
            ProtectDreamSheet(
                onClose: {
                    isProtectDreamPresented = false
                },
                onProtected: { impact in
                    pendingBoostImpact = impact
                    homeRefreshToken += 1
                    shouldPresentBoostRevealAfterProtectDream = true
                    isProtectDreamPresented = false
                }
            )
            .delaydPageSheet(detents: [.large])
        }
        .fullScreenCover(isPresented: $isPostRevealProPromptPresented) {
            DelaydProView(
                entryPoint: .postReveal,
                onClose: {
                    isPostRevealProPromptPresented = false
                },
                onSubscribe: { _ in
                    isPostRevealProPromptPresented = false
                },
                onRestore: {
                    isPostRevealProPromptPresented = false
                }
            )
        }
    }

    private var quickActionBackdrop: some View {
        Color.black.opacity(colorScheme == .dark ? 0.38 : 0.16)
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(AppMotion.sheetPresentation) {
                    isQuickActionMenuPresented = false
                }
            }
    }

    /// Produces a QuickLogViewModel seeded with the amount supplied by
    /// QuickLogIntent (Shortcuts / Siri / back-tap). For regular taps we just
    /// use a fresh empty view model.
    /// NOTE: does NOT clear `intentPrefilledAmount` — call `clearIntentPrefill()`
    /// from `onAppear` inside the sheet so state mutation happens outside the
    /// view-update pass (avoids "modifying state during view update" warning).
    @MainActor
    private func quickLogViewModelForPresentation() -> QuickLogViewModel {
        guard let prefill = intentPrefilledAmount, prefill > 0 else {
            return QuickLogViewModel()
        }
        let amountText: String
        if prefill.rounded() == prefill {
            amountText = String(Int(prefill))
        } else {
            amountText = String(format: "%.2f", prefill)
        }
        return QuickLogViewModel(amountText: amountText)
    }

    @MainActor
    private func clearIntentPrefill() {
        intentPrefilledAmount = nil
    }

    private func dismissReveal(shouldOfferProPrompt: Bool = false) {
        withAnimation(.easeOut(duration: 0.18)) {
            isRevealPresented = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            pendingImpact = nil
            homeRefreshToken += 1

            guard shouldOfferProPrompt else { return }
            presentPostRevealProPromptIfNeeded()
        }
    }

    private func dismissBoostReveal() {
        withAnimation(.easeOut(duration: 0.18)) {
            isBoostRevealPresented = false
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            pendingBoostImpact = nil
            homeRefreshToken += 1
        }
    }

    private func undoPendingImpactAndDismiss() {
        guard let impact = pendingImpact, let expenseId = impact.expenseId else {
            dismissReveal()
            return
        }

        Task {
            let repository = ExpenseRepository(modelContainer: modelContext.container)
            await repository.undoImpact(
                expenseId: expenseId,
                goalId: impact.affectedGoal.id,
                previousAmount: impact.previousAmount
            )

            await MainActor.run {
                dismissReveal()
            }
        }
    }

    @MainActor
    private func presentPostRevealProPromptIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: postRevealProPromptShownKey) else { return }
        UserDefaults.standard.set(true, forKey: postRevealProPromptShownKey)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            isPostRevealProPromptPresented = true
        }
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var appShell: some View {
        selectedScreen
            .safeAreaInset(edge: .bottom, spacing: 0) {
                DelaydTabBar(
                    selectedTab: selectedTab,
                    onSelect: { tab in selectedTab = tab },
                    onLog: {
                        withAnimation(AppMotion.sheetPresentation) {
                            isQuickActionMenuPresented.toggle()
                        }
                    }
                )
            }
            .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private var selectedScreen: some View {
        switch selectedTab {
        case .home:
            HomeView(
                viewModel: homeViewModel,
                refreshToken: homeRefreshToken,
                onOpenSettings: { selectedTab = .settings },
                onOpenHistory: { selectedTab = .history },
                onProtectDream: { isProtectDreamPresented = true },
                onOpenSavedHistory: { isSavedHistoryPresented = true }
            )
        case .plan:
            PlanView()
        case .history:
            HistoryView(refreshToken: historyRefreshToken)
        case .settings:
            SettingsView()
        }
    }
}

private enum DelaydTab: CaseIterable, Hashable, Identifiable {
    case home
    case plan
    case history
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "Home"
        case .plan: "Plan"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .plan: "square.grid.2x2"
        case .history: "clock"
        case .settings: "gearshape"
        }
    }

    var filledSystemImage: String {
        switch self {
        case .home: "house.fill"
        case .plan: "square.grid.2x2.fill"
        case .history: "clock.fill"
        case .settings: "gearshape.fill"
        }
    }

    /// Phosphor (Bold weight) custom symbol shipped via Assets.xcassets.
    /// Matches the Paylix-style icon vibe better than the SF Symbol set.
    var phosphorIcon: PhosphorIcon.Name {
        switch self {
        case .home: .house
        case .plan: .wallet
        case .history: .chartBar
        case .settings: .gearSix
        }
    }
}

// MARK: - Global Action Menu

private struct QuickActionMenu: View {
    let onLogSpend: () -> Void
    let onProtectDream: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            actionButton(
                icon: "minus.circle.fill",
                title: "Log Spend",
                subtitle: "See how this delays the dream",
                tint: AppColors.negative,
                action: onLogSpend
            )

            actionButton(
                icon: "checkmark.shield.fill",
                title: "Protect Dream",
                subtitle: "Add money already kept aside",
                tint: AppColors.positive,
                action: onProtectDream
            )
        }
        .padding(AppSpacing.sm)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.10), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 430)
    }

    private func actionButton(
        icon: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary(for: colorScheme))
            }
            .padding(AppSpacing.md)
            .background(AppColors.softSurface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tab Bar

private struct TabBarShape: Shape {
    let cornerRadius: CGFloat
    let cutoutRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX
        let cr = cornerRadius
        let r = cutoutRadius

        // Start top-left corner
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + cr))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + cr, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        // Left lead into cutout
        p.addLine(to: CGPoint(x: cx - r - 14, y: rect.minY))

        // Cutout curve (half-circle down and back up)
        p.addCurve(
            to: CGPoint(x: cx, y: rect.minY + r),
            control1: CGPoint(x: cx - r, y: rect.minY),
            control2: CGPoint(x: cx - r, y: rect.minY + r)
        )
        p.addCurve(
            to: CGPoint(x: cx + r + 14, y: rect.minY),
            control1: CGPoint(x: cx + r, y: rect.minY + r),
            control2: CGPoint(x: cx + r, y: rect.minY)
        )

        // Right side to top-right corner
        p.addLine(to: CGPoint(x: rect.maxX - cr, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cr),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        // Down, across, back to start
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct DelaydTabBar: View {
    let selectedTab: DelaydTab
    let onSelect: (DelaydTab) -> Void
    let onLog: () -> Void
    /// When non-nil (iPad wide layout), the bar is centred inside this width.
    /// `nil` means edge-to-edge (iPhone default).
    var maxWidth: CGFloat? = nil

    @Environment(\.colorScheme) private var colorScheme

    private let barHeight: CGFloat = 78
    private let fabSize: CGFloat = 62
    private let cutoutGap: CGFloat = 10
    private let cornerRadius: CGFloat = 24
    private let bottomExtension: CGFloat = 34

    var body: some View {
        let cutoutRadius = (fabSize / 2) + cutoutGap
        let totalHeight = barHeight + bottomExtension

        // One continuous container: the cutout remains at the top, while the
        // same shape extends into the bottom safe area. Tab items stay inside
        // the upper band so labels have breathing room above the home indicator.
        ZStack(alignment: .top) {
            TabBarShape(cornerRadius: cornerRadius, cutoutRadius: cutoutRadius)
                .fill(AppColors.tabBar(for: colorScheme))
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                    radius: 12, x: 0, y: -4
                )
                .overlay(
                    TabBarShape(cornerRadius: cornerRadius, cutoutRadius: cutoutRadius)
                        .stroke(AppColors.border(for: colorScheme), lineWidth: 0.5)
                )
                .frame(height: totalHeight)
                .ignoresSafeArea(edges: .bottom)

            // Tab items row — FAB gap is always centred inside the pill
            HStack(spacing: 0) {
                tabButton(.home)
                tabButton(.plan, trailingSpace: 48)
                tabButton(.history, leadingSpace: 48)
                tabButton(.settings)
            }
            .padding(.top, 18)
            .padding(.bottom, 14)
            .frame(height: barHeight)

            // FAB — centred in the cutout
            Button(action: onLog) {
                ZStack {
                    Circle()
                        .fill(AppGradients.heroGradient)
                        .shadow(color: AppColors.purplePrimary.opacity(0.45), radius: 14, x: 0, y: 6)

                    PhosphorIcon(.plus, size: 26)
                        .foregroundStyle(.white)
                }
                .frame(width: fabSize, height: fabSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log impact")
            .offset(y: -(fabSize / 2) + 4)
        }
        .frame(maxWidth: maxWidth ?? .infinity, alignment: .center)
        .frame(height: totalHeight)
        .padding(.bottom, -bottomExtension)
    }

    @ViewBuilder
    private func tabButton(
        _ tab: DelaydTab,
        leadingSpace: CGFloat = 0,
        trailingSpace: CGFloat = 0
    ) -> some View {
        let isSelected = selectedTab == tab
        let selectedColor = AppColors.textPrimary(for: colorScheme)
        let unselectedColor = AppColors.textTertiary(for: colorScheme)
        Button(action: { onSelect(tab) }) {
            VStack(spacing: 4) {
                PhosphorIcon(tab.phosphorIcon, size: 24)
                    .foregroundStyle(isSelected ? selectedColor : unselectedColor)
                    .opacity(isSelected ? 1 : 0.85)
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? selectedColor : unselectedColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, leadingSpace)
        .padding(.trailing, trailingSpace)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Root Light") {
    RootView(onboardingCompleted: true)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Root Dark") {
    RootView(onboardingCompleted: true)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}

#Preview("Onboarding First Launch") {
    RootView(onboardingCompleted: false)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Official iOS Tab Bar") {
    RootView(onboardingCompleted: true)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}
