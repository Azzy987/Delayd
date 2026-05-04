import SwiftUI
import SwiftData

struct ProfileSheet: View {
    var onClose: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onOpenPro: (() -> Void)?

    @State private var isHelpPresented = false
    @State private var isSharePresented = false
    @State private var shareItems: [Any] = []
    @State private var stats = ProfileStats.empty
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.lg) {
                    identityCard
                        .padding(.top, AppSpacing.lg)

                    statsGrid

                    proBanner

                    linksCard

                    Text("Guest mode · Data stored on this device")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textTertiary(for: colorScheme))
                        .padding(.top, AppSpacing.sm)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
        .sheet(isPresented: $isHelpPresented) {
            ProfileHelpSheet()
                .delaydPageSheet(detents: [.height(280)])
        }
        .sheet(isPresented: $isSharePresented) {
            DelaydShareSheet(items: shareItems)
                .presentationDetents([.medium, .large])
        }
        .task {
            stats = await ProfileStats.load(modelContext: modelContext)
        }
    }

    private var header: some View {
        HStack {
            Text("Profile")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            Spacer()
            Button {
                onClose?()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .frame(width: 32, height: 32)
                    .background(AppColors.surface(for: colorScheme), in: Circle())
                    .overlay(Circle().stroke(AppColors.border(for: colorScheme), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private var identityCard: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(AppGradients.heroGradient)
                    .frame(width: 96, height: 96)
                    .shadow(color: AppColors.purplePrimary.opacity(0.35), radius: 18, x: 0, y: 8)
                Image(systemName: "person.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text("You")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                Text(stats.identitySubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: AppSpacing.md), GridItem(.flexible(), spacing: AppSpacing.md)],
            spacing: AppSpacing.md
        ) {
            statTile(value: "\(stats.daysTracked)", label: "Days tracked", tint: AppColors.purplePrimary, background: AppColors.softPurpleBackground)
            statTile(value: "\(stats.goalsProtected)", label: "Goals protected", tint: Color(red: 0.10, green: 0.48, blue: 0.30), background: Color(red: 0.85, green: 0.96, blue: 0.89))
            statTile(value: stats.savedThisMonthText, label: "Saved this month", tint: Color(red: 0.35, green: 0.55, blue: 1.0), background: Color(red: 0.88, green: 0.92, blue: 1.0))
            statTile(value: "\(stats.delayDaysThisMonth)d", label: "Delay this month", tint: Color(red: 0.72, green: 0.36, blue: 0.10), background: Color(red: 1.0, green: 0.90, blue: 0.82))
        }
    }

    private func statTile(value: String, label: String, tint: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(background, in: RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    private var proBanner: some View {
        Button {
            onOpenPro?()
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.2), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Delayd Pro")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Unlock richer insights")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(AppSpacing.md)
            .background(AppGradients.heroGradient, in: RoundedRectangle(cornerRadius: AppRadius.lg))
            .shadow(color: AppColors.purplePrimary.opacity(0.28), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            linkRow(systemImage: "gearshape.fill", title: "Open Settings") {
                onOpenSettings?()
            }
            Divider().overlay(AppColors.border(for: colorScheme))
            Button {
                shareProgress()
            } label: {
                linkRowContent(systemImage: "square.and.arrow.up", title: "Share your progress")
            }
            .buttonStyle(.plain)
            Divider().overlay(AppColors.border(for: colorScheme))
            linkRow(systemImage: "questionmark.circle", title: "Help & Support") {
                isHelpPresented = true
            }
        }
        .background(AppColors.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        )
    }

    private func linkRow(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            linkRowContent(systemImage: systemImage, title: title)
        }
        .buttonStyle(.plain)
    }

    private func linkRowContent(systemImage: String, title: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.purplePrimary)
                .frame(width: 30, height: 30)
                .background(AppColors.softPurpleBackground, in: RoundedRectangle(cornerRadius: 10))

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary(for: colorScheme))
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
        .contentShape(Rectangle())
    }

    @MainActor
    private func shareProgress() {
        let url = AppShare.progressCardURL(
            title: "Dreams protected",
            subtitle: stats.identitySubtitle,
            amount: stats.savedThisMonthText,
            progressText: "saved this month",
            progress: stats.savedThisMonth > 0 ? 0.64 : 0.12,
            category: .savings
        )
        shareItems = [url as Any, AppShare.profileText(goalsProtected: stats.goalsProtected)].compactMap { $0 }
        isSharePresented = true
    }
}

private struct ProfileHelpSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Help & Support")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                helpRow(icon: "target", title: "Goals", detail: "Create one dream first so every logged expense has a timeline impact.")
                helpRow(icon: "plus.circle.fill", title: "Quick Log", detail: "Use the center button to enter an expense and see the delay reveal.")
                helpRow(icon: "lock.fill", title: "Privacy", detail: "V1 data stays local on this device.")
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    private func helpRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.purplePrimary)
                .frame(width: 32, height: 32)
                .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                Text(detail)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Profile stats

struct ProfileStats {
    var daysTracked: Int
    var goalsProtected: Int
    var savedThisMonth: Double
    var delayDaysThisMonth: Int
    var firstActivityDate: Date?
    var currencyCode: String

    static let empty = ProfileStats(
        daysTracked: 0,
        goalsProtected: 0,
        savedThisMonth: 0,
        delayDaysThisMonth: 0,
        firstActivityDate: nil,
        currencyCode: "USD"
    )

    var savedThisMonthText: String {
        let value = max(0, savedThisMonth)
        return CurrencyFormatter.format(value, currencyCode: currencyCode)
    }

    /// "Protecting 3 dreams since April 2026" — derived from real data so the
    /// copy isn't a hardcoded "April 2026" any more.
    var identitySubtitle: String {
        let goalCount = max(goalsProtected, 0)
        let dreamWord = goalCount == 1 ? "dream" : "dreams"
        let countWord = goalCount > 0 ? "\(goalCount) \(dreamWord)" : "your dreams"

        guard let start = firstActivityDate else {
            return "Protecting \(countWord) — local-first."
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return "Protecting \(countWord) since \(formatter.string(from: start))"
    }

    @MainActor
    static func load(modelContext: ModelContext) async -> ProfileStats {
        let goals = (try? modelContext.fetch(FetchDescriptor<Goal>(
            predicate: #Predicate { !$0.isArchived }
        ))) ?? []

        let expenses = (try? modelContext.fetch(FetchDescriptor<Expense>())) ?? []
        let events = (try? modelContext.fetch(FetchDescriptor<ImpactEvent>())) ?? []

        let calendar = Calendar.current
        let now = Date()

        // Days tracked = number of distinct calendar days the user has logged
        // expenses on. Better signal than "days since first activity".
        let trackedDays = Set(expenses.map { calendar.startOfDay(for: $0.occurredAt) }).count

        let monthRange = calendar.dateInterval(of: .month, for: now)

        let settings = (try? modelContext.fetch(FetchDescriptor<UserSettings>()))?.first
        let contributions = (try? modelContext.fetch(FetchDescriptor<DreamContribution>())) ?? []
        let saved = contributions
            .filter { monthRange?.contains($0.occurredAt) ?? false }
            .reduce(0.0) { $0 + $1.amount }

        // Total delay days from impact events in the current month.
        let delayDays = events
            .filter { monthRange?.contains($0.calculatedAt) ?? false }
            .reduce(0) { $0 + max(0, $1.delayDays) }

        let firstActivity = (
            expenses.map(\.occurredAt) + goals.map(\.createdAt)
        ).min()

        return ProfileStats(
            daysTracked: trackedDays,
            goalsProtected: goals.count,
            savedThisMonth: saved,
            delayDaysThisMonth: delayDays,
            firstActivityDate: firstActivity,
            currencyCode: settings?.defaultCurrency ?? CurrencyFormatter.localeDefaultCurrencyCode
        )
    }
}

#Preview("Profile Light") {
    ProfileSheet()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Profile Dark") {
    ProfileSheet()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
