import SwiftUI
import SwiftData

struct PlanView: View {
    @State private var viewModel: PlanViewModel
    let refreshToken: Int
    @State private var isCreateGoalPresented = false
    @State private var isAllGoalsPresented = false
    @State private var isGoalSwitcherPresented = false
    @State private var goalToEdit: PlanGoal?
    @State private var goalToDelete: PlanGoal?
    @State private var isDeleteConfirmationPresented = false
    @State private var isProPresented = false
    @State private var isProUnlocked = ProEntitlementService.isUnlocked
    @State private var shareItems: [Any] = []
    @State private var isSharePresented = false
    @State private var isPreparingShare = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.iPadContentInset) private var hInset

    @MainActor
    init(viewModel: PlanViewModel? = nil, refreshToken: Int = 0) {
        _viewModel = State(initialValue: viewModel ?? PlanViewModel())
        self.refreshToken = refreshToken
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.sm)

                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        loadedContent
                    }
                }
                .padding(.bottom, 140)
                // iPad: extra side inset so content sits in a centred ~560pt
                // column. Background still spans full width. No-op on iPhone.
                .padding(.horizontal, hInset)
            }
            .background(AppColors.softSurface(for: colorScheme))
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $isAllGoalsPresented) {
                allGoalsList
                    .navigationTitle("My Goals")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar(.visible, for: .navigationBar)
            }
            .sheet(isPresented: $isCreateGoalPresented) {
                CreateGoalSheet(
                    onClose: {
                        isCreateGoalPresented = false
                    },
                    onCreate: { goal in
                        isProUnlocked = ProEntitlementService.isUnlocked
                        guard isProUnlocked || goalsCountForFreeLimit == 0 else {
                            isCreateGoalPresented = false
                            isProPresented = true
                            return
                        }
                        Task {
                            await viewModel.addGoal(goal, modelContainer: modelContext.container)
                            isCreateGoalPresented = false
                        }
                    }
                )
                .delaydPageSheet(detents: [.large])
            }
            .sheet(item: $goalToEdit) { goal in
                CreateGoalSheet(
                    editingGoal: goal,
                    onClose: { goalToEdit = nil },
                    onCreate: { edited in
                        Task {
                            await viewModel.updateGoal(edited, modelContainer: modelContext.container)
                            goalToEdit = nil
                        }
                    }
                )
                .delaydPageSheet(detents: [.large])
            }
            .sheet(isPresented: $isGoalSwitcherPresented) {
                GoalSwitcherSheet(
                    title: "Switch Goal",
                    subtitle: "Choose which dream appears first in Plan.",
                    selectedGoalId: viewModel.featuredGoal?.id,
                    onSelect: { goalId in
                        isGoalSwitcherPresented = false
                        Task {
                            let settingsRepository = SettingsRepository(modelContainer: modelContext.container)
                            await settingsRepository.update { settings in
                                settings.defaultGoalId = goalId
                            }
                            await viewModel.load(modelContainer: modelContext.container)
                        }
                    },
                    onCreateNew: {
                        isGoalSwitcherPresented = false
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(260))
                            createGoalTapped()
                        }
                    }
                )
                .delaydPageSheet(detents: [.height(520), .large])
            }
            .fullScreenCover(isPresented: $isProPresented) {
                DelaydProView(
                    onClose: { isProPresented = false },
                    onSubscribe: { _ in
                        isProUnlocked = true
                        isProPresented = false
                        isCreateGoalPresented = true
                    },
                    onRestore: {
                        isProUnlocked = true
                        isProPresented = false
                        isCreateGoalPresented = true
                    }
                )
            }
            .background(
                DelaydActivityPresenter(isPresented: $isSharePresented, items: shareItems)
                    .frame(width: 0, height: 0)
            )
            .confirmationDialog(
                "Delete \(goalToDelete?.displayName ?? "this goal")?",
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("Delete Goal", role: .destructive) {
                    if let goal = goalToDelete {
                        Task {
                            await viewModel.deleteGoal(goal, modelContainer: modelContext.container)
                            goalToDelete = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) { goalToDelete = nil }
            } message: {
                Text("This will permanently remove the goal and all its linked data.")
            }
        }
        .task(id: refreshToken) {
            await viewModel.load(modelContainer: modelContext.container)
        }
        .overlay {
            if isPreparingShare {
                preparingShareOverlay
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: AppSpacing.md) {
                Text("My Plan")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    createGoalTapped()
                } label: {
                    PhosphorIcon(.plus, size: 18)
                        .foregroundStyle(AppColors.card(for: colorScheme))
                        .frame(width: 36, height: 36)
                        .background(AppColors.textPrimary(for: colorScheme), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create goal")

                Button {
                    shareFeaturedGoal()
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppColors.card(for: colorScheme))
                        Circle()
                            .stroke(AppColors.border(for: colorScheme), lineWidth: 1)

                        if isPreparingShare {
                            ProgressView()
                                .controlSize(.small)
                                .tint(AppColors.textPrimary(for: colorScheme))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        }
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isEmpty || isPreparingShare)
                .opacity((viewModel.isEmpty || isPreparingShare) ? 0.45 : 1)
                .accessibilityLabel("Share goals")
            }
        }
    }

    // MARK: - Content

    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            sectionHeader(title: "Goals", actionTitle: nil) {}
                .padding(.horizontal, AppSpacing.lg)

            HStack {
                Spacer()
                Button {
                    isGoalSwitcherPresented = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Switch Goal")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.purplePrimary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, -AppSpacing.sm)

            if let featured = viewModel.featuredGoal {
                NavigationLink {
                    GoalDetailView(goal: featured)
                } label: {
                    featuredGoalCard(featured)
                        .padding(.horizontal, AppSpacing.lg)
                }
                .buttonStyle(.plain)
            }

            if viewModel.remainingGoals.isEmpty {
                HStack {
                    Text("My Goals")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    Spacer()
                    Button {
                        isAllGoalsPresented = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("View All")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.purplePrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xs)

                Text("No additional goals yet. Tap + to add another dream.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.md)
                    .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                    }
                    .padding(.horizontal, AppSpacing.lg)
            } else {
                HStack {
                    Text("My Goals")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    Spacer()
                    Button {
                        isAllGoalsPresented = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("View All")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.purplePrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xs)

                VStack(spacing: AppSpacing.md) {
                    ForEach(viewModel.remainingGoals) { goal in
                        NavigationLink {
                            GoalDetailView(goal: goal)
                        } label: {
                            budgetRow(goal: goal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
    }

    private func sectionHeader(title: String, actionTitle: String? = nil, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            Spacer()
            if let actionTitle {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.purplePrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Featured goal

    private func featuredGoalCard(_ goal: PlanGoal) -> some View {
        let statusColor = featuredStatusColor(for: goal)
        let statusText = featuredStatusText(for: goal)

        return VStack(spacing: 0) {
            // White card top
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .center, spacing: AppSpacing.md) {
                    GoalCategoryIcon(category: goal.category, size: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        Text(goal.timelineSummaryText)
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Menu {
                        Button {
                            goalToEdit = goal
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }

                        ShareLink(item: AppShare.goalText(goal)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            goalToDelete = goal
                            isDeleteConfirmationPresented = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        PhosphorIcon(.dotsThreeVertical, size: 18)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(AppColors.softSurface(for: colorScheme))
                            )
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(goal.formattedCurrentAmount)
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    Text("Out of \(goal.formattedTargetAmount)")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }

                featuredProgressBar(goal: goal, color: statusColor)

                HStack {
                    Text("Your Progress")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    Spacer()
                    Text("\(goal.formattedDifference) Left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                }
            }
            .padding(AppSpacing.lg)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 20, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 20
                )
                .fill(AppColors.card(for: colorScheme))
            )

            HStack(spacing: AppSpacing.sm) {
                PhosphorIcon(.info, size: 15)
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)

                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 38)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0, bottomLeadingRadius: 20,
                    bottomTrailingRadius: 20, topTrailingRadius: 0
                )
                .fill(statusColor)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.04), radius: 10, x: 0, y: 2)
    }

    private func featuredProgressBar(goal: PlanGoal, color: Color) -> some View {
        GeometryReader { geo in
            let progress = LayoutGuard.unit(CGFloat(goal.progress), name: "PlanView.featuredProgress")
            let trackHeight: CGFloat = 10
            let overshootWidth: CGFloat = min(0.18, 1 - progress)
            let hatchWidth = LayoutGuard.dimension(
                geo.size.width * LayoutGuard.unit(progress + overshootWidth, name: "PlanView.featuredHatchProgress"),
                name: "PlanView.featuredHatchWidth"
            )
            let fillWidth = LayoutGuard.dimension(geo.size.width * progress, name: "PlanView.featuredFillWidth")
            let knobOffset = LayoutGuard.scalar((geo.size.width * progress) - 8, name: "PlanView.featuredKnobOffset")

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(goal.category.backgroundColor.opacity(0.5))
                    .frame(height: trackHeight)

                // hatched overshoot section
                Capsule()
                    .fill(
                        ImagePaint(
                            image: hatchedImage(tint: color),
                            scale: 1
                        )
                    )
                    .frame(width: hatchWidth, height: trackHeight)
                    .mask(
                        Capsule()
                            .frame(width: hatchWidth, height: trackHeight)
                    )

                // solid fill
                Capsule()
                    .fill(color)
                    .frame(width: fillWidth, height: trackHeight)

                Circle()
                    .fill(AppColors.card(for: colorScheme))
                    .overlay(Circle().stroke(color, lineWidth: 3))
                    .frame(width: 16, height: 16)
                    .offset(x: knobOffset)
            }
        }
        .frame(height: 18)
    }

    // MARK: - Budget rows

    private func budgetRow(goal: PlanGoal) -> some View {
        HStack(spacing: AppSpacing.md) {
            GoalCategoryIcon(category: goal.category, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                HStack(spacing: 4) {
                    Text(goal.formattedCurrentAmount)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    Text("of \(goal.formattedTargetAmount)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }
            }

            Spacer()

            CircleBadge(
                progress: CGFloat(goal.progress),
                color: goal.category.accentColor,
                background: goal.category.backgroundColor
            )
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.04), radius: 8, x: 0, y: 2)
    }

    // MARK: - Helpers

    private func defaultWarning(for goal: PlanGoal) -> String? {
        if goal.aheadDays > 0 {
            return "You're \(goal.aheadDays) \(goal.aheadDays == 1 ? "day" : "days") ahead of schedule."
        }
        return goal.delayedDays > 0 ? "You're 30% behind schedule and off target." : nil
    }

    private func featuredStatusText(for goal: PlanGoal) -> String {
        if let warning = goal.warningText ?? defaultWarning(for: goal) {
            if warning.localizedCaseInsensitiveContains("behind schedule"),
               !warning.localizedCaseInsensitiveContains("off target") {
                return warning.hasSuffix(".")
                    ? warning.replacingOccurrences(of: ".", with: " and off target.")
                    : "\(warning) and off target."
            }

            return warning.hasSuffix(".") ? warning : "\(warning)."
        }

        return "Protect this dream by logging every spend against it."
    }

    private func featuredStatusColor(for goal: PlanGoal) -> Color {
        if goal.aheadDays > 0 {
            return AppColors.positive
        }
        if goal.warningText != nil || goal.delayedDays > 0 {
            return AppColors.warning
        }

        return goal.category.accentColor
    }

    private func hatchedImage(tint: Color) -> Image {
        HatchedImageCache.shared.image(for: tint)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppSpacing.lg) {
            sectionHeader(title: "Goals", actionTitle: "View All") {
                isAllGoalsPresented = true
            }
                .padding(.horizontal, AppSpacing.lg)

            EmptyStateCard(
                systemImage: "target",
                assetImageName: "EmptyGoal",
                title: "No dreams protected yet",
                description: "Create one goal so every expense can show what it did to your timeline.",
                ctaTitle: "Create goal",
                action: {
                    createGoalTapped()
                }
            )
            .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.top, AppSpacing.xl)
    }

    private var allGoalsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                ForEach(viewModel.goals) { goal in
                    NavigationLink {
                        GoalDetailView(goal: goal)
                    } label: {
                        budgetRow(goal: goal)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.background(for: colorScheme))
    }

    private var shareSummaryText: String {
        guard let featured = viewModel.featuredGoal else {
            return "I'm protecting my dreams with Delayd.\n\nGet Delayd: \(AppShare.appLink)"
        }

        return AppShare.goalText(featured)
    }

    @MainActor
    private func shareFeaturedGoal() {
        guard !isPreparingShare else { return }
        guard let featured = viewModel.featuredGoal else { return }
        isPreparingShare = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))

            let image = AppShare.progressCardImage(
                title: featured.displayName,
                subtitle: "Every spend shows the days it moves this dream.",
                amount: "\(featured.formattedCurrentAmount) of \(featured.formattedTargetAmount)",
                progressText: "\(featured.percentageText) protected",
                progress: featured.progress,
                category: featured.category
            )

            var items: [Any] = [shareSummaryText]
            if let image {
                items.insert(image, at: 0)
            }

            guard !items.isEmpty else {
                isPreparingShare = false
                return
            }

            shareItems = items
            isPreparingShare = false
            isSharePresented = true
        }
    }

    private var preparingShareOverlay: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.44 : 0.18)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.sm) {
                ProgressView()
                    .controlSize(.regular)
                Text("Preparing share…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
            }
        }
        .transition(.opacity)
    }

    private func createGoalTapped() {
        isProUnlocked = ProEntitlementService.isUnlocked
        guard isProUnlocked || goalsCountForFreeLimit == 0 else {
            isProPresented = true
            return
        }
        isCreateGoalPresented = true
    }

    private var goalsCountForFreeLimit: Int {
        viewModel.goals.filter { $0.targetAmount > 0 }.count
    }
}

// MARK: - Hatched image cache

private final class HatchedImageCache {
    static let shared = HatchedImageCache()
    private var cache: [String: Image] = [:]

    func image(for tint: Color) -> Image {
        let key = UIColor(tint).description
        if let cached = cache[key] { return cached }

        let size = CGSize(width: 10, height: 10)
        let renderer = UIGraphicsImageRenderer(size: size)
        let ui = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor(tint).withAlphaComponent(0.35).setStroke()
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.move(to: CGPoint(x: -2, y: size.height + 2))
            ctx.cgContext.addLine(to: CGPoint(x: size.width + 2, y: -2))
            ctx.cgContext.strokePath()
        }
        let image = Image(uiImage: ui)
        cache[key] = image
        return image
    }
}

// MARK: - Circle badge

private struct CircleBadge: View {
    let progress: CGFloat
    let color: Color
    let background: Color

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        ZStack {
            Circle()
                .fill(background.opacity(0.92))
                .frame(width: 46, height: 46)

            Circle()
                .stroke(.white, lineWidth: 1)
                .frame(width: 42, height: 42)

            Circle()
                .stroke(background.opacity(0.72), lineWidth: 3)
                .frame(width: 48, height: 48)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(-90))

            Text("\(Int((clamped * 100).rounded()))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 52, height: 52)
    }
}

// MARK: - PlanGoal helper

private extension PlanGoal {
    var formattedDifference: String {
        let delta = max(targetAmount - currentAmount, 0)
        return CurrencyFormatter.format(delta, currencyCode: currencyCode)
    }
}

#Preview("Plan Light") {
    PlanView(viewModel: .mock())
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Plan Empty") {
    PlanView(viewModel: .empty())
        .modelContainer(PreviewContainer.empty)
        .preferredColorScheme(.light)
}
