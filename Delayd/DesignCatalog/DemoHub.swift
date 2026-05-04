import SwiftUI
import SwiftData

struct DemoHub: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Design System") {
                    NavigationLink("DesignSystemCatalog") {
                        DesignSystemCatalog()
                    }
                }

                Section("Components") {
                    NavigationLink("BrandLogoView") { ComponentShowcase(kind: .brandLogo) }
                    NavigationLink("GoalCategoryIcon") { ComponentShowcase(kind: .goalCategoryIcon) }
                    NavigationLink("GoalHeroCard") { ComponentShowcase(kind: .goalHeroCard) }
                    NavigationLink("GoalCard") { ComponentShowcase(kind: .goalCard) }
                    NavigationLink("DelayedImpactCard") { ComponentShowcase(kind: .delayedImpactCard) }
                    NavigationLink("ExpenseRow") { ComponentShowcase(kind: .expenseRow) }
                    NavigationLink("SmartInsightCard") { ComponentShowcase(kind: .smartInsightCard) }
                    NavigationLink("BackwardProgressBar") { ComponentShowcase(kind: .backwardProgressBar) }
                    NavigationLink("ValueDeltaChip") { ComponentShowcase(kind: .valueDeltaChip) }
                    NavigationLink("TagChip") { ComponentShowcase(kind: .tagChip) }
                    NavigationLink("EmptyStateCard") { ComponentShowcase(kind: .emptyStateCard) }
                    NavigationLink("SectionHeader") { ComponentShowcase(kind: .sectionHeader) }
                    NavigationLink("GoalEmojiPicker") { ComponentShowcase(kind: .goalEmojiPicker) }
                    NavigationLink("GoalCategoryIllustrationPicker") { ComponentShowcase(kind: .goalCategoryIllustrationPicker) }
                    NavigationLink("OnboardingIllustration") { ComponentShowcase(kind: .onboardingIllustration) }
                    NavigationLink("Buttons") { ComponentShowcase(kind: .buttons) }
                }

                Section("Onboarding") {
                    NavigationLink("Full Flow") { OnboardingView(viewModel: OnboardingViewModel.mock(), showsDebugControls: true) }
                    NavigationLink("Welcome") { OnboardingScreenShowcase(kind: .welcome) }
                    NavigationLink("Insight") { OnboardingScreenShowcase(kind: .insight) }
                    NavigationLink("Choose Dream") { OnboardingScreenShowcase(kind: .chooseDream) }
                    NavigationLink("Goal Details") { OnboardingScreenShowcase(kind: .goalDetails) }
                    NavigationLink("Savings Target") { OnboardingScreenShowcase(kind: .savingsTarget) }
                    NavigationLink("Starting Savings") { OnboardingScreenShowcase(kind: .startingSavings) }
                    NavigationLink("Tone") { OnboardingScreenShowcase(kind: .tone) }
                    NavigationLink("Permissions") { OnboardingScreenShowcase(kind: .permissions) }
                    NavigationLink("Ready") { OnboardingScreenShowcase(kind: .ready) }
                }

                Section("Screens") {
                    NavigationLink("Home") { HomeView() }
                    NavigationLink("Plan — Default") { PlanView(viewModel: .mock()) }
                    NavigationLink("Plan — Empty") { PlanView(viewModel: .empty()) }
                    NavigationLink("Goal Detail") { NavigationStack { GoalDetailView(goal: PlanGoal.mockGoals[0]) } }
                    NavigationLink("Create Goal") { CreateGoalShowcase() }
                    NavigationLink("History — Loaded") { HistoryView(viewModel: .mock()) }
                    NavigationLink("History — Empty") { HistoryView(viewModel: .empty()) }
                    NavigationLink("Settings") { SettingsView(viewModel: .mock()) }
                }

                Section("⭐ Money Shot") {
                    NavigationLink("Quick Log Sheet") {
                        MoneyShotShowcase(kind: .quickLog)
                    }
                    NavigationLink("Protect Dream Sheet") {
                        MoneyShotShowcase(kind: .protectDream)
                    }
                    NavigationLink("Protect Reveal") {
                        MoneyShotShowcase(kind: .protectReveal)
                    }
                    NavigationLink("Reveal — Small (₹150)") {
                        MoneyShotShowcase(kind: .small)
                    }
                    NavigationLink("Reveal — Medium (₹500)") {
                        MoneyShotShowcase(kind: .medium)
                    }
                    NavigationLink("Reveal — Large (₹2,500)") {
                        MoneyShotShowcase(kind: .large)
                    }
                    NavigationLink("Reveal — Emergency (₹50,000)") {
                        MoneyShotShowcase(kind: .emergency)
                    }
                }
            }
            .navigationTitle("Delayd Demo Hub")
        }
    }
}

private struct CreateGoalShowcase: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPresented = true

    var body: some View {
        ZStack {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            Text("Create Goal")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
        }
        .sheet(isPresented: $isPresented) {
            CreateGoalSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .navigationTitle("Create Goal")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MoneyShotShowcase: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isQuickLogPresented = true
    let kind: Kind

    var body: some View {
        Group {
            switch kind {
            case .quickLog:
                ZStack {
                    AppColors.background(for: colorScheme)
                        .ignoresSafeArea()

                    Text("Quick Log Sheet")
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                }
                .sheet(isPresented: $isQuickLogPresented) {
                    QuickLogSheet(viewModel: .mock(amount: "500"))
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            case .protectDream:
                ZStack {
                    AppColors.background(for: colorScheme)
                        .ignoresSafeArea()

                    Text("Protect Dream Sheet")
                        .font(AppTypography.sectionHeader)
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                }
                .sheet(isPresented: $isQuickLogPresented) {
                    ProtectDreamSheet(viewModel: .mock(amount: "5000"))
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            case .protectReveal:
                DreamBoostRevealView(
                    impact: DreamBoostImpact(
                        amount: 5_000,
                        daysCloser: 15,
                        affectedGoal: .mockBali,
                        previousProgress: 0.21,
                        newProgress: 0.25,
                        previousAmount: 25_000,
                        newAmount: 30_000,
                        location: .piggyBank,
                        currencyCode: "INR",
                        previousTargetDate: Calendar.current.date(byAdding: .month, value: 8, to: .now),
                        improvedTargetDate: Calendar.current.date(byAdding: .day, value: -15, to: Calendar.current.date(byAdding: .month, value: 8, to: .now) ?? .now)
                    ),
                    onDismiss: {}
                )
            case .small:
                DelayedImpactRevealView(impact: .mockSmall)
            case .medium:
                DelayedImpactRevealView(impact: .mockMedium)
            case .large:
                DelayedImpactRevealView(impact: .mockLarge)
            case .emergency:
                DelayedImpactRevealView(impact: .mockEmergency)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension MoneyShotShowcase {
    enum Kind {
        case quickLog
        case protectDream
        case protectReveal
        case small
        case medium
        case large
        case emergency

        var title: String {
            switch self {
            case .quickLog: "Quick Log Sheet"
            case .protectDream: "Protect Dream Sheet"
            case .protectReveal: "Protect Reveal"
            case .small: "Reveal — Small"
            case .medium: "Reveal — Medium"
            case .large: "Reveal — Large"
            case .emergency: "Reveal — Emergency"
            }
        }
    }
}

private struct OnboardingScreenShowcase: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDream: GoalCategory? = .travel
    @State private var goalName = "Bali trip"
    @State private var goalAmount = "120000"
    @State private var goalDate: Date? = Calendar.current.date(byAdding: .month, value: 12, to: .now)
    @State private var monthlyTarget = "10000"
    @State private var startingSavedAmount = "5000"
    @State private var savingsLocation: DreamSavingsLocation = .piggyBank
    @State private var notificationsEnabled = false
    @State private var hapticsEnabled = true
    @State private var selectedTone: DelaydTone = .motivational

    let kind: Kind

    var body: some View {
        content
            .background(AppColors.background(for: colorScheme))
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .welcome:
            WelcomeScreen()
        case .insight:
            InsightScreen()
        case .chooseDream:
            ChooseDreamScreen(selectedDream: $selectedDream)
        case .goalDetails:
            GoalDetailsScreen(
                goalName: $goalName,
                goalAmount: $goalAmount,
                goalDate: $goalDate,
                selectedDream: selectedDream
            )
        case .savingsTarget:
            SavingsTargetScreen(monthlyTarget: $monthlyTarget, goalAmount: $goalAmount, goalDate: $goalDate)
        case .startingSavings:
            StartingSavingsScreen(
                startingSavedAmount: $startingSavedAmount,
                savingsLocation: $savingsLocation,
                goalName: $goalName,
                goalAmount: $goalAmount,
                monthlyTarget: $monthlyTarget,
                goalDate: $goalDate
            )
        case .tone:
            ToneScreen(selectedTone: $selectedTone)
        case .permissions:
            PermissionsScreen(
                notificationsEnabled: $notificationsEnabled,
                hapticsEnabled: $hapticsEnabled
            )
        case .ready:
            ReadyScreen()
        }
    }
}

private extension OnboardingScreenShowcase {
    enum Kind {
        case welcome
        case insight
        case chooseDream
        case goalDetails
        case savingsTarget
        case startingSavings
        case tone
        case permissions
        case ready

        var title: String {
            switch self {
            case .welcome: "Welcome"
            case .insight: "Insight"
            case .chooseDream: "Choose Dream"
            case .goalDetails: "Goal Details"
            case .savingsTarget: "Savings Target"
            case .startingSavings: "Starting Savings"
            case .tone: "Tone"
            case .permissions: "Permissions"
            case .ready: "Ready"
            }
        }
    }
}

private struct ComponentShowcase: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedCategory: GoalCategory = .travel
    @State private var delayedProgress = true
    let kind: Kind

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(kind.title)
                    .font(AppTypography.sectionHeader)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                content
            }
            .padding(AppSpacing.lg)
        }
        .background(AppColors.background(for: colorScheme))
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .brandLogo: 
            HStack(alignment: .bottom, spacing: AppSpacing.lg) {
                BrandLogoView(size: .small)
                BrandLogoView(size: .medium)
                BrandLogoView(size: .large)
                BrandLogoView(size: .icon)
            }
        case .goalCategoryIcon:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: AppSpacing.md)], spacing: AppSpacing.md) {
                ForEach(GoalCategory.pickerPresets) { category in
                    GoalCategoryIcon(category: category)
                }
            }
        case .goalHeroCard:
            GoalHeroCard.mockOnPace()
            GoalHeroCard.mockDelayed()
            GoalHeroCard.mockEdgeCase()
        case .goalCard:
            GoalCard.mock()
            GoalCard.mockBehindSchedule()
            GoalCard.mockEdgeCase()
        case .delayedImpactCard:
            DelayedImpactCard.mock()
            DelayedImpactCard.mockSmallImpact()
            DelayedImpactCard.mockEdgeCase()
        case .expenseRow:
            VStack(spacing: AppSpacing.md) {
                ExpenseRow.mock()
                Divider()
                ExpenseRow.mockEdgeCase()
            }
            .delaydCard()
        case .smartInsightCard:
            SmartInsightCard.mock(index: 0)
            SmartInsightCard.mock(index: 1)
            SmartInsightCard.mockEdgeCase()
        case .backwardProgressBar:
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                BackwardProgressBar(currentProgress: delayedProgress ? 0.36 : 0.72, previousProgress: delayedProgress ? 0.72 : 0.36, accentColor: delayedProgress ? AppColors.negative : AppColors.positive)
                SecondaryButton(delayedProgress ? "Recover progress" : "Show delay") {
                    delayedProgress.toggle()
                }
            }
            .delaydCard()
        case .valueDeltaChip:
            HStack(spacing: AppSpacing.sm) {
                ValueDeltaChip.mock()
                ValueDeltaChip.mockNegative()
                ValueDeltaChip("On pace")
            }
        case .tagChip:
            HStack(spacing: AppSpacing.sm) {
                TagChip("My Hobby", variant: .purple, showsDismiss: true)
                TagChip("Vacation", variant: .warning)
                TagChip("On pace", variant: .positive)
            }
        case .emptyStateCard:
            EmptyStateCard.mock()
            EmptyStateCard.mockNoExpenses()
        case .sectionHeader:
            VStack(spacing: AppSpacing.lg) {
                SectionHeader.mock()
                SectionHeader("Smart insights")
                SectionHeader("Goals that moved this week", actionTitle: "Manage")
            }
            .delaydCard()
        case .goalEmojiPicker:
            GoalEmojiPicker(selectedCategory: $selectedCategory)
                .delaydCard()
        case .goalCategoryIllustrationPicker:
            GoalCategoryIllustrationPicker(
                selectedCategory: Binding(
                    get: { selectedCategory },
                    set: { if let cat = $0 { selectedCategory = cat } }
                )
            )
        case .onboardingIllustration:
            VStack(spacing: AppSpacing.lg) {
                ZStack {
                    AppGradients.heroGradient
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))

                    LottieAnimationView("LottieWelcome", size: 200)
                }

                ZStack {
                    AppGradients.heroGradient
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))

                    LottieAnimationView("LottieInsight", size: 180)
                }
            }
        case .buttons:
            VStack(spacing: AppSpacing.md) {
                PrimaryButton.mock()
                SecondaryButton.mock()
                FloatingActionButton.mock()
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private extension ComponentShowcase {
    enum Kind {
        case brandLogo
        case goalCategoryIcon
        case goalHeroCard
        case goalCard
        case delayedImpactCard
        case expenseRow
        case smartInsightCard
        case backwardProgressBar
        case valueDeltaChip
        case tagChip
        case emptyStateCard
        case sectionHeader
        case goalEmojiPicker
        case goalCategoryIllustrationPicker
        case onboardingIllustration
        case buttons

        var title: String {
            switch self {
            case .brandLogo: "BrandLogoView"
            case .goalCategoryIcon: "GoalCategoryIcon"
            case .goalHeroCard: "GoalHeroCard"
            case .goalCard: "GoalCard"
            case .delayedImpactCard: "DelayedImpactCard"
            case .expenseRow: "ExpenseRow"
            case .smartInsightCard: "SmartInsightCard"
            case .backwardProgressBar: "BackwardProgressBar"
            case .valueDeltaChip: "ValueDeltaChip"
            case .tagChip: "TagChip"
            case .emptyStateCard: "EmptyStateCard"
            case .sectionHeader: "SectionHeader"
            case .goalEmojiPicker: "GoalEmojiPicker"
            case .goalCategoryIllustrationPicker: "GoalCategoryIllustrationPicker"
            case .onboardingIllustration: "OnboardingIllustration"
            case .buttons: "Buttons"
            }
        }
    }
}

#Preview("Demo Hub Light") {
    DemoHub()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Demo Hub Dark") {
    DemoHub()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
