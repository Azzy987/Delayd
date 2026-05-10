import SwiftData
import SwiftUI
import Observation

@Observable
@MainActor
final class HomeViewModel {
    var activeGoal: PlanGoal?
    var recentImpacts: [HistoryImpact]
    var savedThisMonth: Double
    var savedDeltaText: String?
    var spentThisMonth: Double
    var delayedThisMonth: Int
    var delayedEntriesThisMonth: [HistoryImpact]
    var savedEntriesThisMonth: [HomeSavedEntry]
    var insight: String
    /// Last 7 daily delay totals (oldest → newest). Drives the WeeklyPulse
    /// sparkline. Always 7 entries; days with no expenses are zero.
    var weeklyPulse: [Int]
    /// Daily delay totals for the prior 7-day window (days -13 → -7). Used
    /// to compose the personal-pulse comparison line (e.g. "18 days saved
    /// vs. last month"). Always 7 entries.
    var previousWeeklyPulse: [Int]
    /// Rupees moved into the active goal in the current calendar month.
    /// Drives the "protected your dream" pulse copy.
    var protectedThisMonth: Double
    var goalPaceWarning: String?
    var weeklyRecap: String
    var unreadNotificationCount: Int
    var hasLoaded: Bool

    init(
        activeGoal: PlanGoal? = nil,
        recentImpacts: [HistoryImpact] = [],
        savedThisMonth: Double = 0,
        savedDeltaText: String? = nil,
        spentThisMonth: Double = 0,
        delayedThisMonth: Int = 0,
        delayedEntriesThisMonth: [HistoryImpact] = [],
        savedEntriesThisMonth: [HomeSavedEntry] = [],
        insight: String = "Skipping this 4x/month would put your goal 8 days closer",
        weeklyPulse: [Int] = Array(repeating: 0, count: 7),
        previousWeeklyPulse: [Int] = Array(repeating: 0, count: 7),
        protectedThisMonth: Double = 0,
        goalPaceWarning: String? = nil,
        weeklyRecap: String = "No weekly recap yet.",
        unreadNotificationCount: Int = 0,
        hasLoaded: Bool = false
    ) {
        self.activeGoal = activeGoal
        self.recentImpacts = recentImpacts
        self.savedThisMonth = savedThisMonth
        self.savedDeltaText = savedDeltaText
        self.spentThisMonth = spentThisMonth
        self.delayedThisMonth = delayedThisMonth
        self.delayedEntriesThisMonth = delayedEntriesThisMonth
        self.savedEntriesThisMonth = savedEntriesThisMonth
        self.insight = insight
        self.weeklyPulse = weeklyPulse
        self.previousWeeklyPulse = previousWeeklyPulse
        self.protectedThisMonth = protectedThisMonth
        self.goalPaceWarning = goalPaceWarning
        self.weeklyRecap = weeklyRecap
        self.unreadNotificationCount = unreadNotificationCount
        self.hasLoaded = hasLoaded
    }

    var hasData: Bool {
        activeGoal != nil
    }

    /// ISO 4217 currency code loaded from `UserSettings`. Drives all amount
    /// formatting so the currency picker in Settings has an immediate effect.
    /// Defaults to the device locale so the first frame matches the user's
    /// region (avoids a flash of `$` on Indian devices before settings load).
    var currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode

    var savedThisMonthText: String {
        CurrencyFormatter.format(savedThisMonth, currencyCode: currencyCode)
    }

    var delayedThisMonthText: String {
        "\(delayedThisMonth) days"
    }

    var spentThisMonthText: String {
        CurrencyFormatter.format(spentThisMonth, currencyCode: currencyCode)
    }

    func load(modelContainer: ModelContainer, month: Date = .now) async {
        let goalRepository = GoalRepository(modelContainer: modelContainer)
        let expenseRepository = ExpenseRepository(modelContainer: modelContainer)
        let contributionRepository = DreamContributionRepository(modelContainer: modelContainer)
        let settingsRepository = SettingsRepository(modelContainer: modelContainer)

        let settingsSnapshot = await settingsRepository.fetchSnapshot()
        let settings = await settingsRepository.fetch()
        let refreshedGoals = await goalRepository.fetchActive()
        let monthInterval = Calendar.current.dateInterval(of: .month, for: month)
        let monthContributions = await contributionRepository.fetchAllSnapshots(in: monthInterval)
        let delayedDaysByGoal = await expenseRepository.totalHistoricalDelayDaysByGoal()
        let calculator = DelayCalculator()

        let loadedCurrencyCode = settingsSnapshot.defaultCurrency
        let netStatusByGoal = await contributionRepository.netStatusByGoal(
            totalDelayDaysByGoal: delayedDaysByGoal,
            monthlySavingsTarget: settings.monthlySavingsTarget
        )
        let activeGoal = refreshedGoals.first { $0.id == settingsSnapshot.defaultGoalId } ?? refreshedGoals.first
        let activeGoalNetStatus = activeGoal.flatMap { netStatusByGoal[$0.id] } ?? .onPace
        let loadedActiveGoal = activeGoal.map {
            return PlanGoal(
                goal: $0,
                delayedDays: activeGoalNetStatus.delayedDays,
                aheadDays: activeGoalNetStatus.aheadDays,
                currencyCode: loadedCurrencyCode
            )
        }

        let allExpenses = await expenseRepository.fetchAllSnapshots(in: nil)
        let monthStart = monthInterval?.start ?? .now
        let monthEnd = monthInterval?.end ?? .now
        let timelineExpenses = allExpenses
            .filter { expense in
                guard expense.occurredAt >= monthStart && expense.occurredAt < monthEnd else { return false }
                guard let activeGoal else { return true }
                return expense.goalId == activeGoal.id
            }
            .sorted { $0.occurredAt > $1.occurredAt }
        let loadedRecentImpacts = timelineExpenses.prefix(5).map { expense in
            let fallbackGoal = refreshedGoals.first ?? .mockBali
            let category = expense.goalCategory ?? fallbackGoal.category
            let goalName = expense.goalName ?? fallbackGoal.name
            let delayDays = calculator.delayDays(forExpense: Decimal(expense.amount), monthlySavingsTarget: Decimal(settings.monthlySavingsTarget))
            return HistoryImpact(
                expenseId: expense.id,
                category: category,
                expenseIconSystemImage: Self.expenseIcon(for: expense),
                merchantName: expense.displayName,
                goalName: goalName,
                delayText: "\(delayDays) \(delayDays == 1 ? "day" : "days")",
                amountText: CurrencyFormatter.formatNegative(expense.amount, currencyCode: loadedCurrencyCode),
                occurredAt: expense.occurredAt,
                amount: expense.amount,
                delayDays: delayDays
            )
        }

        // Compute last-7-days pulse: oldest → newest. Group all logged
        // expenses (not just the recent 5 above) by day, convert each day's
        // total into delay days, and zero-fill missing days.
        let loadedWeeklyPulse = Self.weeklyPulse(
            from: allExpenses,
            monthlySavingsTarget: settings.monthlySavingsTarget,
            calculator: calculator,
            offsetDays: 0
        )
        let loadedPreviousWeeklyPulse = Self.weeklyPulse(
            from: allExpenses,
            monthlySavingsTarget: settings.monthlySavingsTarget,
            calculator: calculator,
            offsetDays: -7
        )
        let loadedWeeklyRecap = Self.weeklyRecap(
            from: allExpenses,
            monthlySavingsTarget: settings.monthlySavingsTarget,
            calculator: calculator,
            currencyCode: loadedCurrencyCode
        )

        let activeGoalMonthContributions = monthContributions.filter { contribution in
            contribution.goalId == activeGoal?.id
        }
        let loadedSavedThisMonth = activeGoalMonthContributions.reduce(0) { $0 + $1.amount }
        let loadedSavedDeltaText: String?
        if let interval = Self.previousMonthInterval(now: month) {
            let previousContributions = await contributionRepository.fetchAllSnapshots(in: interval)
            let previousSaved = previousContributions
                .filter { $0.goalId == activeGoal?.id }
                .reduce(0) { $0 + $1.amount }
            if previousSaved > 0 {
                let delta = ((loadedSavedThisMonth - previousSaved) / previousSaved) * 100
                let rounded = Int(delta.rounded())
                loadedSavedDeltaText = rounded >= 0 ? "+\(rounded)%" : "\(rounded)%"
            } else {
                loadedSavedDeltaText = loadedSavedThisMonth > 0 ? "New" : nil
            }
        } else {
            loadedSavedDeltaText = nil
        }
        let loadedDelayedThisMonth = allExpenses
            .filter { expense in
                guard expense.occurredAt >= monthStart && expense.occurredAt < monthEnd else { return false }
                guard let activeGoal else { return true }
                return expense.goalId == activeGoal.id
            }
            .reduce(0) { total, expense in
                total + calculator.delayDays(
                    forExpense: Decimal(expense.amount),
                    monthlySavingsTarget: Decimal(settings.monthlySavingsTarget)
                )
            }
        let loadedSpentThisMonth = allExpenses
            .filter { expense in
                guard expense.occurredAt >= monthStart && expense.occurredAt < monthEnd else { return false }
                guard let activeGoal else { return true }
                return expense.goalId == activeGoal.id
            }
            .reduce(0) { $0 + $1.amount }
        let loadedDelayedEntriesThisMonth = allExpenses
            .filter { expense in
                guard expense.occurredAt >= monthStart && expense.occurredAt < monthEnd else { return false }
                guard let activeGoal else { return true }
                return expense.goalId == activeGoal.id
            }
            .sorted { $0.occurredAt > $1.occurredAt }
            .map { expense in
                let fallbackGoal = refreshedGoals.first ?? .mockBali
                let category = expense.goalCategory ?? fallbackGoal.category
                let goalName = expense.goalName ?? fallbackGoal.name
                let delayDays = calculator.delayDays(
                    forExpense: Decimal(expense.amount),
                    monthlySavingsTarget: Decimal(settings.monthlySavingsTarget)
                )
                return HistoryImpact(
                    expenseId: expense.id,
                    category: category,
                    expenseIconSystemImage: Self.expenseIcon(for: expense),
                    merchantName: expense.displayName,
                    goalName: goalName,
                    delayText: "\(delayDays) \(delayDays == 1 ? "day" : "days")",
                    amountText: CurrencyFormatter.formatNegative(expense.amount, currencyCode: loadedCurrencyCode),
                    occurredAt: expense.occurredAt,
                    amount: expense.amount,
                    delayDays: delayDays
                )
            }
        let loadedSavedEntriesThisMonth = activeGoalMonthContributions
            .sorted { $0.occurredAt > $1.occurredAt }
            .map { contribution in
                HomeSavedEntry(
                    id: contribution.id,
                    amount: contribution.amount,
                    amountText: CurrencyFormatter.format(contribution.amount, currencyCode: loadedCurrencyCode),
                    locationTitle: contribution.location.title,
                    locationSymbol: contribution.location.symbolName,
                    occurredAt: contribution.occurredAt,
                    isStartingBalance: (contribution.note ?? "")
                        .localizedCaseInsensitiveContains("starting protected amount")
                )
            }

        let loadedProtectedThisMonth = loadedSavedThisMonth
        let loadedGoalPaceWarning = activeGoal.flatMap { goal in
            GoalFeasibility.evaluate(
                targetAmount: goal.targetAmount,
                protectedAmount: goal.currentAmount,
                monthlyTarget: settings.monthlySavingsTarget,
                deadline: goal.deadline,
                currencyCode: loadedCurrencyCode
            )
        }.flatMap { result in
            result.isPossible ? nil : result.message
        }

        // Build the rotating Smart Insight context from real data so the
        // banner cycles through the three V1 variants (skip, %-budget, slip)
        // instead of repeating one line forever.
        let insightContext = Self.buildInsightContext(
            allExpenses: allExpenses,
            weeklyPulse: loadedWeeklyPulse,
            activeGoal: activeGoal,
            activeGoalNetStatus: activeGoalNetStatus,
            monthlySavingsTarget: settings.monthlySavingsTarget,
            calculator: calculator
        )
        let loadedInsight = ToneCopy.smartInsight(tone: settingsSnapshot.tone, context: insightContext)
        let loadedUnreadNotificationCount = NotificationsView.unreadCount(modelContext: ModelContext(modelContainer))

        let shouldAnimate = hasLoaded
        let applyLoadedState = { [self] in
            self.activeGoal = loadedActiveGoal
            self.recentImpacts = loadedRecentImpacts
            self.savedThisMonth = loadedSavedThisMonth
            self.savedDeltaText = loadedSavedDeltaText
            self.spentThisMonth = loadedSpentThisMonth
            self.delayedThisMonth = loadedDelayedThisMonth
            self.delayedEntriesThisMonth = loadedDelayedEntriesThisMonth
            self.savedEntriesThisMonth = loadedSavedEntriesThisMonth
            self.weeklyPulse = loadedWeeklyPulse
            self.previousWeeklyPulse = loadedPreviousWeeklyPulse
            self.protectedThisMonth = loadedProtectedThisMonth
            self.goalPaceWarning = loadedGoalPaceWarning
            self.weeklyRecap = loadedWeeklyRecap
            self.unreadNotificationCount = loadedUnreadNotificationCount
            self.insight = loadedInsight
            self.currencyCode = loadedCurrencyCode
            self.hasLoaded = true
        }

        if shouldAnimate {
            withAnimation(AppMotion.backwardProgress) {
                applyLoadedState()
            }
        } else {
            applyLoadedState()
        }
    }

    /// Compose the InsightContext from the data we already have on hand.
    /// Pure helper so it's easy to unit test later.
    private static func buildInsightContext(
        allExpenses: [ExpenseSnapshot],
        weeklyPulse: [Int],
        activeGoal: Goal?,
        activeGoalNetStatus: NetDelayStatus,
        monthlySavingsTarget: Double,
        calculator: DelayCalculator
    ) -> ToneCopy.InsightContext {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        let weeklyExpenses = allExpenses.filter { $0.occurredAt >= weekStart }

        // Top recurring merchant/tag this week — group by lowercased label,
        // pick the most frequent one with at least 2 occurrences so we don't
        // surface a one-off as "recurring".
        let groupedByLabel = Dictionary(grouping: weeklyExpenses) { expense in
            (expense.merchant ?? expense.tag ?? "").lowercased()
        }.filter { !$0.key.isEmpty }

        var topMerchant: String?
        var topSkipDelta = 0
        if let top = groupedByLabel.max(by: { $0.value.count < $1.value.count }),
           top.value.count >= 2 {
            topMerchant = top.value.first?.merchant ?? top.value.first?.tag ?? top.key
            // Average spend × 4 occurrences/month → delay days saved.
            let avg = top.value.reduce(0.0) { $0 + $1.amount } / Double(top.value.count)
            let projectedMonthlySpend = avg * 4
            topSkipDelta = calculator.delayDays(
                forExpense: Decimal(projectedMonthlySpend),
                monthlySavingsTarget: Decimal(monthlySavingsTarget)
            )
        }

        // % of weekly delay budget. "Budget" = 7 days (one delay-day per
        // calendar day is the natural pacing). Cap at 100 so the copy
        // doesn't read "240% of your budget" which feels punishing past the
        // toughLove threshold.
        let weeklyDelayTotal = weeklyPulse.reduce(0, +)
        let weeklyPercent: Int? = weeklyDelayTotal > 0
            ? min(100, Int((Double(weeklyDelayTotal) / 7.0) * 100))
            : nil

        // Goal slip — how far the active goal has drifted this month.
        // We don't store an "original" projected completion date, so we use
        // month-to-date delay days as the slip amount. Only surfaces when
        // the active goal has a targetDate set and there's measurable slip.
        var slipGoalName: String?
        var slipDays = 0
        if let goal = activeGoal, goal.targetDate != nil {
            let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
            let monthExpenses = allExpenses.filter { $0.occurredAt >= monthStart }
            let monthDelayDays = monthExpenses.reduce(0) { total, expense in
                total + calculator.delayDays(
                    forExpense: Decimal(expense.amount),
                    monthlySavingsTarget: Decimal(monthlySavingsTarget)
                )
            }
            if monthDelayDays > 0 {
                slipGoalName = goal.name
                slipDays = monthDelayDays
            }
        }

        return ToneCopy.InsightContext(
            topRecurringMerchant: topMerchant,
            topRecurringSkipDelta: topSkipDelta,
            weeklyDelayPercent: weeklyPercent,
            slippedGoalName: slipGoalName,
            slippedGoalDays: slipDays,
            isAhead: activeGoalNetStatus.isAhead,
            aheadDays: activeGoalNetStatus.aheadDays,
            hasActivity: !weeklyExpenses.isEmpty
        )
    }

    /// `offsetDays` shifts the 7-day window. `0` is the current week
    /// (today and the prior 6 days); `-7` is the week before that.
    private static func weeklyPulse(
        from expenses: [ExpenseSnapshot],
        monthlySavingsTarget: Double,
        calculator: DelayCalculator,
        offsetDays: Int = 0
    ) -> [Int] {
        let calendar = Calendar.current
        let anchor = calendar.date(byAdding: .day, value: offsetDays, to: calendar.startOfDay(for: .now)) ?? .now
        let today = calendar.startOfDay(for: anchor)
        // Build the 7 day-buckets from oldest (-6) → newest (today)
        let dayKeys: [Date] = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }

        let grouped = Dictionary(grouping: expenses) { calendar.startOfDay(for: $0.occurredAt) }

        return dayKeys.map { day in
            let dayExpenses = grouped[day] ?? []
            return dayExpenses.reduce(0) { total, expense in
                total + calculator.delayDays(
                    forExpense: Decimal(expense.amount),
                    monthlySavingsTarget: Decimal(monthlySavingsTarget)
                )
            }
        }
    }

    private static func weeklyRecap(
        from expenses: [ExpenseSnapshot],
        monthlySavingsTarget: Double,
        calculator: DelayCalculator,
        currencyCode: String
    ) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let weeklyExpenses = expenses.filter { $0.occurredAt >= weekStart }

        guard !weeklyExpenses.isEmpty else {
            return "Quiet week: no logged spends pulled a dream backward."
        }

        let delayedDays = weeklyExpenses.reduce(0) { total, expense in
            total + calculator.delayDays(
                forExpense: Decimal(expense.amount),
                monthlySavingsTarget: Decimal(monthlySavingsTarget)
            )
        }
        let biggest = weeklyExpenses.max { $0.amount < $1.amount }
        let biggestLabel = biggest?.displayName ?? "one spend"
        let totalSpend = weeklyExpenses.reduce(0) { $0 + $1.amount }
        let totalFormatted = CurrencyFormatter.format(totalSpend, currencyCode: currencyCode)

        return "This week: \(totalFormatted) logged, \(delayedDays) delay days, biggest slip was \(biggestLabel)."
    }

    private static func previousMonthInterval(now: Date = .now) -> DateInterval? {
        let calendar = Calendar.current
        guard
            let currentMonth = calendar.dateInterval(of: .month, for: now),
            let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentMonth.start)
        else { return nil }
        return calendar.dateInterval(of: .month, for: previousMonthDate)
    }

    private static func expenseIcon(for expense: ExpenseSnapshot) -> String {
        let label = "\(expense.tag ?? "") \(expense.merchant ?? "")".lowercased()

        if label.contains("coffee") || label.contains("cafe") || label.contains("tea") {
            return "cup.and.saucer.fill"
        }
        if label.contains("dinner") || label.contains("lunch") || label.contains("food") || label.contains("restaurant") || label.contains("dosa") || label.contains("idli") || label.contains("biryani") || label.contains("pizza") || label.contains("burger") {
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

struct HomeSavedEntry: Identifiable, Equatable {
    let id: UUID
    let amount: Double
    let amountText: String
    let locationTitle: String
    let locationSymbol: String
    let occurredAt: Date
    let isStartingBalance: Bool
}

extension HomeViewModel {
    static func mock() -> HomeViewModel {
        HomeViewModel(
            activeGoal: PlanGoal.mockGoals[0],
            recentImpacts: HistoryDaySection.mockSections[0].impacts,
            savedThisMonth: 25_000,
            spentThisMonth: 8_400,
            delayedThisMonth: 4,
            weeklyPulse: [0, 2, 1, 3, 1, 5, 2],
            previousWeeklyPulse: [3, 4, 2, 5, 3, 6, 4],
            protectedThisMonth: 12_400,
            hasLoaded: true
        )
    }
}

#Preview("Home View Model") {
    Text(HomeViewModel.mock().delayedThisMonthText)
        .font(AppTypography.bodyMedium)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
