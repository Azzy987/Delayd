import SwiftUI
import SwiftData

struct NotificationsView: View {
    var onClose: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var items: [NotificationItem] = []
    @State private var dismissedIds: Set<UUID> = NotificationsView.loadDismissed()
    @State private var readIds: Set<UUID> = NotificationsView.loadRead()
    @State private var filter: Filter = .all
    @State private var hasLoaded = false

    enum Filter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

            filterBar
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)

            if visibleItems.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(visibleItems) { item in
                        notificationRow(item)
                            .listRowInsets(EdgeInsets(
                                top: AppSpacing.xs,
                                leading: AppSpacing.md,
                                bottom: AppSpacing.xs,
                                trailing: AppSpacing.md
                            ))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    dismiss(item)
                                } label: {
                                    Label("Dismiss", systemImage: "xmark")
                                }
                                .tint(AppColors.negative)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
        .task {
            // Load real data the first time the screen appears, and reload on
            // subsequent appearances so the inbox always reflects the latest
            // logged expenses without needing manual refresh.
            await load()
            hasLoaded = true
        }
    }

    private var visibleItems: [NotificationItem] {
        filter == .all ? items : items.filter { !$0.isRead }
    }

    private var header: some View {
        HStack {
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .frame(width: 36, height: 36)
                        .background(AppColors.surface(for: colorScheme), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close notifications")
            }

            HStack(spacing: AppSpacing.sm) {
                Text("Notifications")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.purplePrimary, in: Capsule())
                }
            }

            Spacer()

            Button {
                markAllRead()
            } label: {
                Text("Mark all read")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.purplePrimary)
            }
            .buttonStyle(.plain)
            .opacity(unreadCount > 0 ? 1 : 0.35)
            .disabled(unreadCount == 0)
        }
    }

    private var filterBar: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(Filter.allCases, id: \.self) { option in
                let isSelected = filter == option
                Button {
                    filter = option
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : AppColors.textSecondary(for: colorScheme))
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            isSelected ? AnyShapeStyle(AppColors.purplePrimary) : AnyShapeStyle(AppColors.surface(for: colorScheme)),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .stroke(AppColors.border(for: colorScheme), lineWidth: isSelected ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func notificationRow(_ item: NotificationItem) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.kind.tintBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: item.kind.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(item.kind.tintForeground)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .lineLimit(2)

                    if !item.isRead {
                        Circle()
                            .fill(AppColors.purplePrimary)
                            .frame(width: 7, height: 7)
                            .padding(.top, 6)
                    }

                    Spacer(minLength: 0)

                    Button {
                        withAnimation(.easeOut(duration: 0.22)) {
                            dismiss(item)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppColors.textTertiary(for: colorScheme))
                            .frame(width: 24, height: 24)
                            .background(AppColors.softSurface(for: colorScheme), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text(item.body)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .lineLimit(2)

                Text(item.timeAgo)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textTertiary(for: colorScheme))
                    .padding(.top, 2)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            markRead(item)
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.softPurpleBackground)
                    .frame(width: 72, height: 72)
                Image(systemName: "bell.slash")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppColors.purplePrimary)
            }

            Text("You're all caught up")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            Text("We'll nudge you when delays start stacking up.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
    }

    private var unreadCount: Int {
        items.filter { !$0.isRead }.count
    }

    // MARK: - Loading

    /// Build the inbox from recent SwiftData rows. We surface:
    ///   * the most recent delay-causing expenses (top 5, unique per goal)
    ///   * goal milestones at 25 / 50 / 75 / 100% progress
    /// Read/dismissed state is mirrored in `UserDefaults` so it survives
    /// relaunch without adding a new SwiftData model in V1.
    private func load() async {
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived }
        ))) ?? []

        var eventDescriptor = FetchDescriptor<ImpactEvent>(
            sortBy: [SortDescriptor(\ImpactEvent.calculatedAt, order: .reverse)]
        )
        eventDescriptor.fetchLimit = 20
        let recentEvents = (try? modelContext.fetch(eventDescriptor)) ?? []

        var built: [NotificationItem] = []

        // Delay nudges from recent ImpactEvents that actually moved a goal.
        for event in recentEvents.prefix(5) where event.delayDays > 0 {
            let goal = goals.first { $0.id == event.goalId }
            let goalLabel = goal?.name.delaydGoalTitleCased ?? "your goal"
            built.append(NotificationItem(
                id: event.id,
                kind: .delayNudge,
                title: "\(goalLabel) slipped \(event.delayDays) day\(event.delayDays == 1 ? "" : "s")",
                body: "A recent expense pushed \(goalLabel) further out. Tap History to review.",
                timeAgo: NotificationsView.relative(from: event.calculatedAt),
                isRead: readIds.contains(event.id)
            ))
        }

        // Milestone notifications — one per goal per crossed threshold.
        for goal in goals where goal.targetAmount > 0 {
            let progress = goal.currentAmount / goal.targetAmount
            let milestone: Double? = [1.0, 0.75, 0.50, 0.25].first { progress >= $0 }
            if let m = milestone {
                let id = Self.milestoneId(goalId: goal.id, threshold: m)
                let pct = Int(m * 100)
                built.append(NotificationItem(
                    id: id,
                    kind: .goalMilestone,
                    title: "\(goal.name.delaydGoalTitleCased) hit \(pct)%",
                    body: pct == 100
                        ? "You're there. Time to celebrate this dream."
                        : "Halfway counts. Keep the streak alive — each clean day adds days back.",
                    timeAgo: "Now",
                    isRead: readIds.contains(id)
                ))
            }
        }

        // Filter out user-dismissed items.
        items = built.filter { !dismissedIds.contains($0.id) }
    }

    // Synthetic id for a (goal, threshold) milestone. Stable so dismissing it
    // once persists across relaunches.
    private static func relative(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    // MARK: - Actions

    private func markRead(_ item: NotificationItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isRead = true
        readIds.insert(item.id)
        Self.persistRead(readIds)
    }

    private func dismiss(_ item: NotificationItem) {
        items.removeAll { $0.id == item.id }
        dismissedIds.insert(item.id)
        Self.persistDismissed(dismissedIds)
    }

    private func markAllRead() {
        items = items.map {
            var copy = $0
            copy.isRead = true
            readIds.insert($0.id)
            return copy
        }
        Self.persistRead(readIds)
    }

    // MARK: - UserDefaults persistence

    private static let dismissedKey = "delayd.notifications.dismissed"
    private static let readKey = "delayd.notifications.read"

    static func unreadCount(modelContext: ModelContext) -> Int {
        let readIds = loadRead()
        let dismissedIds = loadDismissed()
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived }
        ))) ?? []

        var eventDescriptor = FetchDescriptor<ImpactEvent>(
            sortBy: [SortDescriptor(\ImpactEvent.calculatedAt, order: .reverse)]
        )
        eventDescriptor.fetchLimit = 20
        let recentEvents = (try? modelContext.fetch(eventDescriptor)) ?? []

        var ids: [UUID] = recentEvents
            .prefix(5)
            .filter { $0.delayDays > 0 }
            .map(\.id)

        for goal in goals where goal.targetAmount > 0 {
            let progress = goal.currentAmount / goal.targetAmount
            if let milestone = [1.0, 0.75, 0.50, 0.25].first(where: { progress >= $0 }) {
                ids.append(milestoneId(goalId: goal.id, threshold: milestone))
            }
        }

        return ids.filter { !readIds.contains($0) && !dismissedIds.contains($0) }.count
    }

    private static func milestoneId(goalId: UUID, threshold: Double) -> UUID {
        let seed = "\(goalId.uuidString)-\(Int(threshold * 100))"
        return UUID(seed: seed)
    }

    static func loadDismissed() -> Set<UUID> {
        decodeIds(UserDefaults.standard.array(forKey: dismissedKey) as? [String] ?? [])
    }

    static func loadRead() -> Set<UUID> {
        decodeIds(UserDefaults.standard.array(forKey: readKey) as? [String] ?? [])
    }

    private static func decodeIds(_ array: [String]) -> Set<UUID> {
        Set(array.compactMap { UUID(uuidString: $0) })
    }

    private static func persistDismissed(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map { $0.uuidString }, forKey: dismissedKey)
    }

    private static func persistRead(_ ids: Set<UUID>) {
        UserDefaults.standard.set(ids.map { $0.uuidString }, forKey: readKey)
    }
}

struct NotificationItem: Identifiable {
    enum Kind {
        case delayNudge
        case goalMilestone
        case weeklyInsight
        case reminder

        var systemImage: String {
            switch self {
            case .delayNudge: "hourglass.bottomhalf.filled"
            case .goalMilestone: "checkmark.seal.fill"
            case .weeklyInsight: "sparkles"
            case .reminder: "bell.fill"
            }
        }

        var tintForeground: Color {
            switch self {
            case .delayNudge: Color(red: 0.72, green: 0.36, blue: 0.10)
            case .goalMilestone: Color(red: 0.10, green: 0.48, blue: 0.30)
            case .weeklyInsight: AppColors.purplePrimary
            case .reminder: Color(red: 0.35, green: 0.55, blue: 1.0)
            }
        }

        var tintBackground: Color {
            switch self {
            case .delayNudge: Color(red: 1.0, green: 0.90, blue: 0.82)
            case .goalMilestone: Color(red: 0.85, green: 0.96, blue: 0.89)
            case .weeklyInsight: AppColors.softPurpleBackground
            case .reminder: Color(red: 0.88, green: 0.92, blue: 1.0)
            }
        }
    }

    let id: UUID
    let kind: Kind
    let title: String
    let body: String
    let timeAgo: String
    var isRead: Bool
}

// Stable UUID derived from a string seed (deterministic so milestone IDs stay
// the same across relaunches and the user's dismiss/read state persists).
private extension UUID {
    init(seed: String) {
        let hash = abs(seed.hashValue)
        var bytes = [UInt8](repeating: 0, count: 16)
        var h = hash
        for i in 0..<8 {
            bytes[i] = UInt8(h & 0xFF)
            h >>= 8
        }
        let suffix = seed.unicodeScalars.prefix(8)
        for (i, scalar) in suffix.enumerated() {
            bytes[8 + i] = UInt8(scalar.value & 0xFF)
        }
        self = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

#Preview("Notifications Light") {
    NotificationsView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Notifications Dark") {
    NotificationsView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
