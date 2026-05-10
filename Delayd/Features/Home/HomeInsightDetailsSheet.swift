import SwiftUI

struct DelayedThisMonthDetailsSheet: View {
    let currencyCode: String
    let delayedDays: Int
    let spentAmount: Double
    let entries: [HistoryImpact]
    var onClose: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack {
                    Text("Delayed This Month")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    Spacer()
                    if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                .frame(width: 34, height: 34)
                                .background(AppColors.card(for: colorScheme), in: Circle())
                                .overlay(Circle().stroke(AppColors.border(for: colorScheme), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close Delayed This Month")
                    }
                }

                HStack(spacing: AppSpacing.md) {
                    metricCard(
                        title: "Total spent",
                        value: CurrencyFormatter.format(spentAmount, currencyCode: currencyCode),
                        tint: AppColors.textPrimary(for: colorScheme)
                    )
                    metricCard(
                        title: "Delay impact",
                        value: "\(delayedDays) days",
                        tint: AppColors.negative
                    )
                }

                if entries.isEmpty {
                    EmptyStateCard(
                        systemImage: "wallet.pass.fill",
                        assetImageName: "ImpactReveal",
                        title: "No delayed spends this month",
                        description: "Once you log a spend, its delay impact will show here."
                    )
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Transactions")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                        ForEach(entries) { entry in
                            delayedEntryRow(entry)
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    private func metricCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private func delayedEntryRow(_ impact: HistoryImpact) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: impact.expenseIconSystemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.negative)
                .frame(width: 32, height: 32)
                .background(AppColors.softNegativeBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(impact.merchantName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .lineLimit(1)
                Text("\(impact.delayText) delay • \(impact.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            }

            Spacer(minLength: 0)

            Text(impact.amountText)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.negative)
        }
        .padding(AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }
}

struct InsightDetailsSheet: View {
    let insightText: String
    let currencyCode: String
    let savedAmount: Double
    let spentAmount: Double
    let delayedDays: Int
    let savedEntries: [HomeSavedEntry]
    let delayedEntries: [HistoryImpact]
    var onClose: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(alignment: .center) {
                    Text("Smart Insight")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                    Spacer()

                    if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                                .frame(width: 34, height: 34)
                                .background(AppColors.card(for: colorScheme), in: Circle())
                                .overlay(Circle().stroke(AppColors.border(for: colorScheme), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close Smart Insight")
                    }
                }

                Text(insightText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppSpacing.md)
                    .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.lg)
                            .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                    }

                SpendVsSaveDonutChart(
                    savedAmount: savedAmount,
                    spentAmount: spentAmount,
                    currencyCode: currencyCode
                )

                HStack(spacing: AppSpacing.md) {
                    summaryMetric(
                        title: "Saved",
                        value: CurrencyFormatter.format(savedAmount, currencyCode: currencyCode),
                        tint: AppColors.positive
                    )
                    summaryMetric(
                        title: "Spent",
                        value: CurrencyFormatter.format(spentAmount, currencyCode: currencyCode),
                        tint: AppColors.negative
                    )
                    summaryMetric(
                        title: "Delay",
                        value: "\(delayedDays)d",
                        tint: AppColors.warning
                    )
                }

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    sectionTitle("Recent timeline")
                    if combinedTimeline.isEmpty {
                        EmptyStateCard(
                            systemImage: "clock",
                            assetImageName: "EmptyGoal",
                            title: "No entries this month",
                            description: "Protected amounts and spending impacts will appear here by time."
                        )
                    } else {
                        VStack(spacing: AppSpacing.sm) {
                            ForEach(combinedTimeline.prefix(8)) { item in
                                switch item {
                                case .protected(let entry):
                                    savedEntryRow(entry)
                                case .spent(let entry):
                                    expenseEntryRow(entry)
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
    }

    private func summaryMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 58, alignment: .topLeading)
        .padding(AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private var combinedTimeline: [InsightTimelineItem] {
        let protected = savedEntries.map(InsightTimelineItem.protected)
        let spent = delayedEntries.map(InsightTimelineItem.spent)
        return (protected + spent).sorted { $0.occurredAt > $1.occurredAt }
    }

    private func savedEntryRow(_ entry: HomeSavedEntry) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: entry.locationSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.positive)
                .frame(width: 30, height: 30)
                .background(AppColors.softPositiveBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isStartingBalance ? "Starting protected amount" : entry.locationTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                Text("\(entry.amountText) protected here. Your dream stayed closer instead of drifting.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textTertiary(for: colorScheme))
            }

            Spacer(minLength: 0)

            Text("+\(entry.amountText)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.positive)
        }
        .padding(AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private func expenseEntryRow(_ entry: HistoryImpact) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: entry.expenseIconSystemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.negative)
                .frame(width: 30, height: 30)
                .background(AppColors.softNegativeBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.merchantName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                Text("\(entry.amountText) moved \(entry.goalName.delaydGoalTitleCased) by \(entry.delayText).")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.textTertiary(for: colorScheme))
            }

            Spacer(minLength: 0)

            Text(entry.amountText)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.negative)
        }
        .padding(AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }
}

private enum InsightTimelineItem: Identifiable {
    case protected(HomeSavedEntry)
    case spent(HistoryImpact)

    var id: String {
        switch self {
        case .protected(let entry):
            return "protected-\(entry.id.uuidString)"
        case .spent(let entry):
            return "spent-\(entry.id.uuidString)"
        }
    }

    var occurredAt: Date {
        switch self {
        case .protected(let entry):
            return entry.occurredAt
        case .spent(let entry):
            return entry.occurredAt
        }
    }
}

private struct SpendVsSaveDonutChart: View {
    let savedAmount: Double
    let spentAmount: Double
    let currencyCode: String

    @Environment(\.colorScheme) private var colorScheme

    private var sanitizedSaved: Double {
        savedAmount.isFinite ? max(savedAmount, 0) : 0
    }

    private var sanitizedSpent: Double {
        spentAmount.isFinite ? max(spentAmount, 0) : 0
    }

    private var total: Double {
        sanitizedSaved + sanitizedSpent
    }

    private var spentRatio: Double {
        guard total > 0 else { return 0.55 }
        return sanitizedSpent / total
    }

    private var savedRatio: Double {
        guard total > 0 else { return 0.45 }
        return sanitizedSaved / total
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .stroke(
                        AppColors.border(for: colorScheme).opacity(colorScheme == .dark ? 0.34 : 0.55),
                        style: StrokeStyle(lineWidth: 28, lineCap: .round)
                    )

                if total > 0 {
                    segment(from: 0.03, length: savedSegmentLength, color: AppColors.positive)
                    segment(from: 0.03 + savedSegmentLength + 0.055, length: spentSegmentLength, color: AppColors.negative)
                } else {
                    segment(from: 0.06, length: 0.36, color: AppColors.positive.opacity(0.55))
                    segment(from: 0.52, length: 0.28, color: AppColors.negative.opacity(0.55))
                    segment(from: 0.86, length: 0.08, color: AppColors.warning.opacity(0.65))
                }

                VStack(spacing: 4) {
                    Text("Total impact")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    Text(CurrencyFormatter.format(total, currencyCode: currencyCode))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .minimumScaleFactor(0.62)
                        .lineLimit(1)
                }
                .padding(.horizontal, AppSpacing.md)
            }
            .frame(width: 210, height: 210)
            .frame(maxWidth: .infinity)

            HStack(spacing: AppSpacing.md) {
                legendDot(color: AppColors.positive, title: "Protected", value: CurrencyFormatter.format(sanitizedSaved, currencyCode: currencyCode))
                legendDot(color: AppColors.negative, title: "Spent", value: CurrencyFormatter.format(sanitizedSpent, currencyCode: currencyCode))
            }
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private var savedSegmentLength: Double {
        max(savedRatio * 0.86, sanitizedSaved > 0 ? 0.045 : 0)
    }

    private var spentSegmentLength: Double {
        max(spentRatio * 0.86, sanitizedSpent > 0 ? 0.045 : 0)
    }

    private func segment(from start: Double, length: Double, color: Color) -> some View {
        let clampedStart = min(max(start, 0), 0.98)
        let clampedEnd = min(clampedStart + max(length, 0), 0.98)
        return Circle()
            .trim(from: clampedStart, to: clampedEnd)
            .stroke(color, style: StrokeStyle(lineWidth: 30, lineCap: .round))
            .rotationEffect(.degrees(-92))
            .shadow(color: color.opacity(colorScheme == .dark ? 0.12 : 0.16), radius: 10, x: 0, y: 4)
    }

    private func legendDot(color: Color, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
