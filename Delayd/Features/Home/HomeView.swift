import SwiftData
import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var isNotificationsPresented = false
    @State private var isProfilePresented = false
    @State private var isProPresented = false
    @State private var isGoalDetailsPresented = false
    @State private var isGoalSwitcherPresented = false
    @State private var isCreateGoalPresented = false
    @State private var isMonthPickerPresented = false
    @State private var isDelayedDetailsPresented = false
    @State private var isInsightDetailsPresented = false
    @State private var selectedImpact: HistoryImpact?
    @State private var selectedMonth = Date()
    @State private var isProUnlocked = ProEntitlementService.isUnlocked
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    let onOpenSettings: () -> Void
    let onOpenHistory: () -> Void
    let onProtectDream: () -> Void
    /// Tap handler for the "Saved this month" card. Distinct from
    /// `onProtectDream` (which is the input flow) so the card opens the
    /// list of past contributions while the floating "+" stays the way to
    /// log a new one. RootView wires this to `SavedHistorySheet`.
    let onOpenSavedHistory: () -> Void
    let refreshToken: Int

    @MainActor
    init(
        viewModel: HomeViewModel? = nil,
        refreshToken: Int = 0,
        onOpenSettings: @escaping () -> Void = {},
        onOpenHistory: @escaping () -> Void = {},
        onProtectDream: @escaping () -> Void = {},
        onOpenSavedHistory: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: viewModel ?? HomeViewModel())
        self.refreshToken = refreshToken
        self.onOpenSettings = onOpenSettings
        self.onOpenHistory = onOpenHistory
        self.onProtectDream = onProtectDream
        self.onOpenSavedHistory = onOpenSavedHistory
    }

    // Recessed background behind the bottom sheet. Uses the theme-aware
    // `softSurface` so it follows light/dark instead of being a hardcoded
    // light grey that looked pure white in dark mode.
    private var sheetBackground: Color {
        AppColors.softSurface(for: colorScheme)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Base layer mirrors the real page structure: a fixed hero zone on top,
                // then the soft sheet surface below. This keeps scroll bounce from
                // exposing an accidental 50/50 split on short or rotated canvases.
                VStack(spacing: 0) {
                    heroBackground
                        .frame(height: homeHeroBackgroundHeight(for: geo) + 96)
                    sheetBackground
                }
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Purple hero section — background and content fill the available width.
                        VStack(spacing: 0) {
                            Color.clear.frame(height: geo.safeAreaInsets.top)
                            topBar
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.top, AppSpacing.sm)
                                .padding(.bottom, AppSpacing.lg)

                            if let goal = viewModel.activeGoal {
                                heroContent(goal: goal)
                                    .padding(.horizontal, AppSpacing.lg)
                                    .padding(.bottom, AppSpacing.xl)
                            }
                        }
                        .background(heroBackground)

                        // Bottom sheet — grey extends to the very bottom
                        bottomSheet
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .navigationBarHidden(true)
        .task(id: refreshToken) {
            isProUnlocked = ProEntitlementService.isUnlocked
            await viewModel.load(modelContainer: modelContext.container, month: selectedMonth)
        }
        .onChange(of: selectedMonth) { _, newValue in
            Task {
                await viewModel.load(modelContainer: modelContext.container, month: newValue)
            }
        }
        .fullScreenCover(
            isPresented: $isNotificationsPresented,
            onDismiss: {
                Task {
                    await viewModel.load(modelContainer: modelContext.container, month: selectedMonth)
                }
            }
        ) {
            NotificationsView(onClose: {
                isNotificationsPresented = false
                Task {
                    await viewModel.load(modelContainer: modelContext.container, month: selectedMonth)
                }
            })
        }
        .sheet(isPresented: $isMonthPickerPresented) {
            MonthPickerSheet(
                months: monthOptions,
                selectedMonth: selectedMonth,
                title: monthTitle(for:),
                onSelect: { month in
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        selectedMonth = month
                    }
                    isMonthPickerPresented = false
                }
            )
            .delaydPageSheet(detents: [.height(440), .medium])
        }
        .sheet(isPresented: $isProfilePresented) {
            ProfileSheet(
                onClose: { isProfilePresented = false },
                onOpenSettings: {
                    isProfilePresented = false
                    onOpenSettings()
                },
                onOpenPro: {
                    isProfilePresented = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(320))
                        isProPresented = true
                    }
                }
            )
            .delaydPageSheet(detents: [.large])
        }
        .sheet(isPresented: $isGoalSwitcherPresented) {
            GoalSwitcherSheet(
                title: "Switch Goal",
                subtitle: "Choose which dream appears on Home.",
                selectedGoalId: viewModel.activeGoal?.id,
                onSelect: { goalId in
                    isGoalSwitcherPresented = false
                    Task {
                        let settingsRepository = SettingsRepository(modelContainer: modelContext.container)
                        await settingsRepository.update { settings in
                            settings.defaultGoalId = goalId
                        }
                        await viewModel.load(modelContainer: modelContext.container, month: selectedMonth)
                    }
                },
                onCreateNew: {
                    isGoalSwitcherPresented = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(260))
                        let goalRepository = GoalRepository(modelContainer: modelContext.container)
                        let activeGoals = await goalRepository.fetchActive()
                        guard ProEntitlementService.isUnlocked || activeGoals.isEmpty else {
                            isProPresented = true
                            return
                        }
                        isCreateGoalPresented = true
                    }
                }
            )
            .delaydPageSheet(detents: [.height(520), .large])
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
                            isProPresented = true
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
                        let settingsRepository = SettingsRepository(modelContainer: modelContext.container)
                        await settingsRepository.update { settings in
                            settings.defaultGoalId = created.id
                        }
                        await viewModel.load(modelContainer: modelContext.container, month: selectedMonth)
                        isCreateGoalPresented = false
                    }
                }
            )
            .delaydPageSheet(detents: [.large])
        }
        .fullScreenCover(isPresented: $isProPresented) {
            DelaydProView(
                onClose: { isProPresented = false },
                onSubscribe: { _ in
                    isProUnlocked = true
                    isProPresented = false
                },
                onRestore: {
                    isProUnlocked = true
                    isProPresented = false
                }
            )
        }
        .fullScreenCover(isPresented: $isGoalDetailsPresented) {
            if let goal = viewModel.activeGoal {
                NavigationStack {
                    GoalDetailView(
                        goal: goal,
                        onClose: { isGoalDetailsPresented = false },
                        onGoalUpdated: {
                            Task {
                                await viewModel.load(modelContainer: modelContext.container, month: selectedMonth)
                            }
                        }
                    )
                }
            }
        }
        .sheet(item: $selectedImpact) { impact in
            ImpactDetailsSheet(
                impact: impact,
                onDelete: {
                    if let expenseId = impact.expenseId {
                        Task {
                            let repository = ExpenseRepository(modelContainer: modelContext.container)
                            await repository.delete(id: expenseId)
                            await viewModel.load(modelContainer: modelContext.container, month: selectedMonth)
                        }
                    }
                }
            )
            .delaydPageSheet(detents: [.height(640), .large])
        }
        .sheet(isPresented: $isDelayedDetailsPresented) {
            DelayedThisMonthDetailsSheet(
                currencyCode: viewModel.currencyCode,
                delayedDays: viewModel.delayedThisMonth,
                spentAmount: viewModel.spentThisMonth,
                entries: viewModel.delayedEntriesThisMonth,
                onClose: { isDelayedDetailsPresented = false }
            )
            .delaydPageSheet(detents: [.large])
        }
        .sheet(isPresented: $isInsightDetailsPresented) {
            InsightDetailsSheet(
                insightText: viewModel.insight,
                currencyCode: viewModel.currencyCode,
                savedAmount: viewModel.savedThisMonth,
                spentAmount: viewModel.spentThisMonth,
                delayedDays: viewModel.delayedThisMonth,
                savedEntries: viewModel.savedEntriesThisMonth,
                delayedEntries: viewModel.delayedEntriesThisMonth,
                onClose: { isInsightDetailsPresented = false }
            )
            .delaydPageSheet(detents: [.large])
        }
    }

    private func homeHeroBackgroundHeight(for geo: GeometryProxy) -> CGFloat {
        let baseHeight: CGFloat = viewModel.goalPaceWarning == nil ? 330 : 410
        return max(geo.safeAreaInsets.top + baseHeight, geo.size.height * 0.36)
    }

    // MARK: - Top bar

    private var heroBackground: some View {
        ZStack {
            AppGradients.heroGradient
            BrandPatternLayer(strength: 0.9)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                isProfilePresented = true
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.25))
                        .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    if isProUnlocked {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.25))
                            .frame(width: 14, height: 14)
                            .background(.white, in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 0.5))
                            .offset(x: 12, y: -12)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")

            Spacer()

            Button {
                isMonthPickerPresented = true
            } label: {
                HStack(spacing: 6) {
                    Text(monthHistoryTitle)
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.white.opacity(0.18))
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select month")

            Spacer()

            Button {
                isNotificationsPresented = true
            } label: {
                ZStack {
                    Image(systemName: viewModel.unreadNotificationCount > 0 ? "bell.fill" : "bell")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.18), in: Circle())

                    if viewModel.unreadNotificationCount > 0 {
                        Circle()
                            .fill(AppColors.negative)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(AppColors.heroGradientStart, lineWidth: 2))
                            .offset(x: 9, y: -8)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
        }
    }

    // MARK: - Hero content

    private func heroContent(goal: PlanGoal) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    isGoalDetailsPresented = true
                } label: {
                    HStack(spacing: 10) {
                        GoalCategoryIcon(category: goal.category, size: 52, style: .hero)
                        Text(goal.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(goal.displayName) details")

                Spacer(minLength: 0)

                Button {
                    isGoalSwitcherPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Switch")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Switch active goal")
            }
            .padding(.bottom, 18)

            Text(goal.formattedCurrentAmount)
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.bottom, 4)

            Text("of \(goal.formattedTargetAmount)")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.bottom, 16)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                Capsule()
                    .fill(.white)
                    .frame(
                        width: LayoutGuard.dimension(
                            geo.size.width * LayoutGuard.unit(CGFloat(goal.progress), name: "HomeView.heroProgress"),
                            name: "HomeView.heroProgressWidth"
                        )
                    )
                    .animation(AppMotion.backwardProgress, value: goal.progress)
            }
            }
            .frame(height: 6)
            .padding(.bottom, 14)

            HStack {
                Text("\(goal.daysRemaining) days remaining")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(goal.heroStatus.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            }

            if let warning = viewModel.goalPaceWarning {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.warning)
                        .padding(.top, 1)

                    Text("Forecast risk: \(warning) You can add side income, one-off top-ups, or trim non-essential spends to close the gap.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppColors.warning.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.warning.opacity(0.55), lineWidth: 1)
                }
                .padding(.top, 14)
            }
        }
    }

    // MARK: - Bottom sheet

    private var bottomSheet: some View {
        let ph = AppSpacing.md
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Your Savings")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                Spacer()
                pillButton("Details") {
                    isGoalDetailsPresented = true
                }
            }
            .padding(.horizontal, ph)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)

            if viewModel.activeGoal != nil {
                HStack(spacing: 12) {
                    savedCardButton
                    delayedCardButton
                }
                .padding(.horizontal, ph)
                .padding(.bottom, AppSpacing.md)

                SmartInsightCard(
                    insightText: viewModel.insight,
                    spentAmountText: CurrencyFormatter.format(viewModel.spentThisMonth, currencyCode: viewModel.currencyCode),
                    trailingTitle: "View",
                    action: { isInsightDetailsPresented = true }
                )
                    .padding(.horizontal, ph)
                    .padding(.bottom, AppSpacing.md)

                WeeklyPulseSection(
                    dailyDelayDays: viewModel.weeklyPulse,
                    previousDailyDelayDays: viewModel.previousWeeklyPulse,
                    protectedThisMonth: viewModel.protectedThisMonth,
                    currencyCode: viewModel.currencyCode
                )
                .padding(.horizontal, ph)
                .padding(.bottom, isProUnlocked ? AppSpacing.md : AppSpacing.lg)

                if isProUnlocked {
                    weeklyRecapCard
                        .padding(.horizontal, ph)
                        .padding(.bottom, AppSpacing.lg)
                }

                HStack {
                    Text("Recent impacts")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    Spacer()
                    pillButton("View All") {
                        onOpenHistory()
                    }
                }
                .padding(.horizontal, ph)
                .padding(.bottom, AppSpacing.sm)

                VStack(spacing: AppSpacing.sm) {
                    ForEach(viewModel.recentImpacts.prefix(5)) { impact in
                        impactRow(impact: impact)
                            .padding(.horizontal, ph)
                    }
                }
            } else if viewModel.hasLoaded {
                EmptyStateCard(
                    systemImage: "target",
                    assetImageName: "EmptyGoal",
                    title: "No dream protected yet",
                    description: "Create a goal to see how every expense moves its timeline.",
                    ctaTitle: "Create goal"
                )
                .padding(.horizontal, ph)
                .padding(.top, AppSpacing.lg)
            }

            // Bottom padding so last row isn't under tab bar + FAB
            Color.clear.frame(height: 140)
        }
        .frame(maxWidth: .infinity)
        .background(
            sheetBackground
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 28, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0, topTrailingRadius: 28
                    )
                )
        )
        .compositingGroup()
    }

    // MARK: - Stat cards

    private var savedCardButton: some View {
        Button(action: onOpenSavedHistory) {
            savedCard
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View Protect Dream history")
    }

    private var delayedCardButton: some View {
        Button(action: { isDelayedDetailsPresented = true }) {
            delayedCard
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View this month's delayed impacts")
    }

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            statIconTile(systemImage: "checkmark.shield.fill", tint: AppColors.positive, background: AppColors.softPositiveBackground)

            HStack(spacing: AppSpacing.xs) {
                Text("Saved this month")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary(for: colorScheme))
            }

            HStack(alignment: .center, spacing: 8) {
                Text(viewModel.savedThisMonthText)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.positive)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if let delta = viewModel.savedDeltaText {
                    Text(delta)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(delta.hasPrefix("-") ? AppColors.warning : AppColors.positive)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            (delta.hasPrefix("-") ? AppColors.softWarningBackground : AppColors.softPositiveBackground)
                                .opacity(colorScheme == .dark ? 0.22 : 1),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .themedCard(colorScheme: colorScheme)
    }

    private var delayedCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            statIconTile(systemImage: "wallet.pass.fill", tint: AppColors.negative, background: AppColors.softNegativeBackground)

            HStack(spacing: AppSpacing.xs) {
                Text("Delayed this month")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary(for: colorScheme))
            }

            Text(viewModel.delayedThisMonthText)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.negative)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .themedCard(colorScheme: colorScheme)
    }

    private var weeklyRecapCard: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.purplePrimary)
                .frame(width: 40, height: 40)
                .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly recap")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                Text(viewModel.weeklyRecap)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .themedCard(colorScheme: colorScheme)
    }

    // MARK: - Impact row

    private func impactRow(impact: HistoryImpact) -> some View {
        Button {
            selectedImpact = impact
        } label: {
            HStack(spacing: 12) {
                spendIconTile(for: impact)

                VStack(alignment: .leading, spacing: 2) {
                    Text(impact.merchantName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .lineLimit(1)

                    Text("Delayed \(impact.goalName.delaydGoalTitleCased) by \(impact.delayText)")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                        .lineLimit(2)
                }

                Spacer()

                Text(impact.amountText)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppColors.negative)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .themedCard(colorScheme: colorScheme)
        }
        .buttonStyle(.plain)
    }

    private func statIconTile(systemImage: String, tint: Color, background: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(background.opacity(colorScheme == .dark ? 0.18 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private func spendIconTile(for impact: HistoryImpact) -> some View {
        let palette = spendPalette(for: impact)
        return Image(systemName: impact.expenseIconSystemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(palette.tint)
            .frame(width: 40, height: 40)
            .background(palette.background.opacity(colorScheme == .dark ? 0.18 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(palette.tint.opacity(colorScheme == .dark ? 0.24 : 0.14), lineWidth: 1)
            }
    }

    private func spendPalette(for impact: HistoryImpact) -> (tint: Color, background: Color) {
        let label = "\(impact.merchantName) \(impact.expenseIconSystemImage)".lowercased()
        if label.contains("coffee") || label.contains("cup") {
            return (Color(red: 0.72, green: 0.36, blue: 0.10), Color(red: 1.0, green: 0.92, blue: 0.84))
        }
        if label.contains("dinner") || label.contains("lunch") || label.contains("food") || label.contains("restaurant") || label.contains("dosa") || label.contains("idli") || label.contains("biryani") || label.contains("pizza") || label.contains("burger") || label.contains("fork") {
            return (AppColors.travelAccent, AppColors.travelBackground)
        }
        if label.contains("shopping") || label.contains("bag") {
            return (AppColors.homeAccent, AppColors.homeBackground)
        }
        if label.contains("car") || label.contains("taxi") || label.contains("ride") {
            return (AppColors.vehicleAccent, AppColors.vehicleBackground)
        }
        if label.contains("travel") || label.contains("airplane") {
            return (AppColors.travelAccent, AppColors.travelBackground)
        }
        if label.contains("health") || label.contains("cross") {
            return (AppColors.positive, AppColors.softPositiveBackground)
        }
        if label.contains("movie") || label.contains("popcorn") || label.contains("game") {
            return (AppColors.techAccent, AppColors.techBackground)
        }
        if label.contains("course") || label.contains("book") {
            return (AppColors.educationAccent, AppColors.educationBackground)
        }
        return (AppColors.purplePrimary, AppColors.softPurpleBackground)
    }

    // MARK: - Helpers

    private func pillButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.purplePrimary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.purplePrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.border(for: colorScheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var monthHistoryTitle: String {
        monthTitle(for: selectedMonth)
    }

    private var monthOptions: [Date] {
        let calendar = Calendar.current
        let currentMonthStart = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        return (-24...24).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: currentMonthStart)
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}

private struct MonthPickerSheet: View {
    let months: [Date]
    let selectedMonth: Date
    let title: (Date) -> String
    let onSelect: (Date) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: true) {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(months, id: \.self) { month in
                            monthRow(month)
                                .id(monthStart(for: month))
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
                }
                .background(AppColors.background(for: colorScheme))
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo(monthStart(for: selectedMonth), anchor: .center)
                    }
                }
            }
            .navigationTitle("Select month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.purplePrimary)
                }
            }
        }
    }

    private func monthRow(_ month: Date) -> some View {
        let isSelected = Calendar.current.isDate(month, equalTo: selectedMonth, toGranularity: .month)
        let isCurrent = Calendar.current.isDate(month, equalTo: .now, toGranularity: .month)

        return Button {
            onSelect(monthStart(for: month))
        } label: {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title(month))
                        .font(.system(size: 17, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                    if isCurrent {
                        Text("Current month")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.purplePrimary)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .fill(isSelected ? AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1) : AppColors.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(isSelected ? AppColors.purplePrimary.opacity(0.28) : AppColors.border(for: colorScheme), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func monthStart(for date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }
}

private extension View {
    /// Card background that follows the current color scheme. Replaces the
    /// old `whiteCard()` which hardcoded white + a faint grey border — that
    /// produced blinding-white cards in dark mode. Shadows are dialed down in
    /// dark mode because black shadows on a dark surface just look muddy.
    func themedCard(colorScheme: ColorScheme) -> some View {
        self
            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.border(for: colorScheme), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.04), radius: 8, x: 0, y: 2)
    }
}

#Preview("Home Light") {
    HomeView(viewModel: .mock())
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Home Dark") {
    HomeView(viewModel: .mock())
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}

#Preview("Home Empty") {
    HomeView(viewModel: HomeViewModel())
        .modelContainer(PreviewContainer.empty)
        .preferredColorScheme(.light)
}

#Preview("Month Picker Light") {
    MonthPickerSheet(
        months: (-6...8).compactMap { Calendar.current.date(byAdding: .month, value: $0, to: .now) },
        selectedMonth: .now,
        title: {
            let formatter = DateFormatter()
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: $0)
        },
        onSelect: { _ in }
    )
    .preferredColorScheme(.light)
}

#Preview("Month Picker Dark") {
    MonthPickerSheet(
        months: (-6...8).compactMap { Calendar.current.date(byAdding: .month, value: $0, to: .now) },
        selectedMonth: .now,
        title: {
            let formatter = DateFormatter()
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: $0)
        },
        onSelect: { _ in }
    )
    .preferredColorScheme(.dark)
}
