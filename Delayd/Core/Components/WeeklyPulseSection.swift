import SwiftUI

/// Minimal "pulse" sparkline showing the last 7 days of delay-day totals.
/// No axes, no grid, no labels under each point — per the V1 blueprint's
/// "no chart axes" rule. Intent is to give the user a calm, glanceable
/// rhythm of recent spending pressure rather than a quantified chart.
struct WeeklyPulseSection: View {
    /// 7 daily totals (oldest → newest). Caller is responsible for ensuring
    /// the array has exactly 7 entries; we render whatever is passed in.
    let dailyDelayDays: [Int]
    /// Daily totals for the prior 7-day window (days -13 → -7). When
    /// supplied, drives a comparison line ("18 days saved vs. last week").
    /// Pass `nil` if the data isn't available yet.
    let previousDailyDelayDays: [Int]?
    /// Rupees the user has moved toward their active goal this calendar
    /// month. When > 0, surfaces the "protected your dream" pulse copy
    /// instead of the raw delay-days line.
    let protectedThisMonth: Double
    /// ISO 4217 currency code — used in the "protected" headline copy.
    var currencyCode: String
    @State private var selectedPoint: CGPoint?
    @State private var selectedIndex: Int?

    @Environment(\.colorScheme) private var colorScheme

    init(
        dailyDelayDays: [Int],
        previousDailyDelayDays: [Int]? = nil,
        protectedThisMonth: Double = 0,
        currencyCode: String = CurrencyFormatter.localeDefaultCurrencyCode
    ) {
        self.dailyDelayDays = dailyDelayDays
        self.previousDailyDelayDays = previousDailyDelayDays
        self.protectedThisMonth = protectedThisMonth
        self.currencyCode = currencyCode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your pulse")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    Text(headlineCopy)
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(rangeLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary(for: colorScheme))
            }

            sparkline
                .frame(height: 56)
        }
        .padding(AppSpacing.md)
        .background(
            AppColors.card(for: colorScheme),
            in: RoundedRectangle(cornerRadius: AppRadius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        )
    }

    /// Picks the most truthful personal-pulse line from the data we have.
    /// Order of preference: protected-amount (positive) → improving week
    /// (delta down) → slow week (delta up) → flat fallback.
    private var headlineCopy: String {
        // Positive: real money moved toward the goal this month.
        if protectedThisMonth > 0 {
            let formatted = CurrencyFormatter.format(protectedThisMonth, currencyCode: currencyCode)
            return "You've protected your dream by \(formatted) this month."
        }

        let currentTotal = dailyDelayDays.reduce(0, +)
        if let previous = previousDailyDelayDays {
            let previousTotal = previous.reduce(0, +)
            let delta = previousTotal - currentTotal

            if delta >= 2 {
                return "You've saved \(delta) days vs. last week."
            }
            if delta <= -2 {
                return "\(-delta) days slower than last week — small choices add up."
            }
        }

        if currentTotal == 0 {
            return "Steady week — nothing pulling your dream back."
        }
        return "\(currentTotal) days delayed across the last week."
    }

    private var rangeLabel: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else {
            return "Last 7d"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekAgo)) – \(formatter.string(from: today))"
    }

    /// Pulse line + soft gradient fill. Resolves the geometry inside a
    /// `Canvas` so we can render a single shape without dropping into UIKit.
    private var sparkline: some View {
        GeometryReader { geo in
            let values = dailyDelayDays.map { CGFloat(max($0, 0)) }
            let maxValue = max(values.max() ?? 1, 1)
            let safeWidth = LayoutGuard.dimension(geo.size.width, name: "WeeklyPulse.width")
            let safeHeight = LayoutGuard.dimension(geo.size.height, name: "WeeklyPulse.height")
            let spacing = values.count > 1 ? safeWidth / CGFloat(values.count - 1) : 0
            // Leave a tiny top/bottom inset so the line never touches edges.
            let inset: CGFloat = 4
            let height = max(safeHeight - inset * 2, 0)

            let points: [CGPoint] = values.enumerated().map { index, value in
                let x = spacing * CGFloat(index)
                let normalized = value / maxValue
                let y = inset + height - (normalized * height)
                return CGPoint(x: x, y: y)
            }

            ZStack {
                // Soft fill under the curve
                fillPath(points: points, height: safeHeight)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.purplePrimary.opacity(0.28),
                                AppColors.purplePrimary.opacity(0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Pulse line itself
                linePath(points: points)
                    .stroke(
                        AppColors.purplePrimary,
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                    )

                // Single emphasis dot on the most recent day so the pulse
                // feels "alive" without becoming a full chart.
                if let last = points.last {
                    Circle()
                        .fill(AppColors.purplePrimary)
                        .frame(width: 8, height: 8)
                        .position(last)
                        .shadow(color: AppColors.purplePrimary.opacity(0.45), radius: 4, x: 0, y: 0)
                }

                if let selectedPoint, let selectedIndex, selectedIndex < values.count {
                    let selectedValue = Int(values[selectedIndex])

                    Path { path in
                        path.move(to: CGPoint(x: selectedPoint.x, y: inset))
                        path.addLine(to: CGPoint(x: selectedPoint.x, y: safeHeight - inset))
                    }
                    .stroke(
                        AppColors.purplePrimary.opacity(0.7),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 4])
                    )

                    Circle()
                        .fill(AppColors.purplePrimary)
                        .frame(width: 10, height: 10)
                        .position(selectedPoint)
                        .shadow(color: AppColors.purplePrimary.opacity(0.45), radius: 4, x: 0, y: 0)

                    Text("\(selectedValue)d")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.purplePrimary, in: Capsule())
                        .position(
                            x: min(max(selectedPoint.x, 24), max(safeWidth - 24, 24)),
                            y: max(selectedPoint.y - 18, 10)
                        )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard !points.isEmpty else { return }
                        let safeX = min(max(gesture.location.x, 0), safeWidth)
                        let rawIndex = spacing > 0 ? Int(round(safeX / spacing)) : 0
                        let index = min(max(rawIndex, 0), points.count - 1)
                        selectedPoint = points[index]
                        selectedIndex = index
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.18)) {
                            selectedPoint = nil
                            selectedIndex = nil
                        }
                    }
            )
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func fillPath(points: [CGPoint], height: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: height))
            path.addLine(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.closeSubpath()
        }
    }
}

#Preview("Weekly Pulse Light") {
    VStack(spacing: 12) {
        // Protected variant
        WeeklyPulseSection(
            dailyDelayDays: [0, 2, 1, 3, 1, 5, 2],
            previousDailyDelayDays: [3, 4, 2, 5, 3, 6, 4],
            protectedThisMonth: 12_400
        )
        // Improving-week variant
        WeeklyPulseSection(
            dailyDelayDays: [0, 1, 0, 1, 1, 0, 1],
            previousDailyDelayDays: [3, 4, 2, 5, 3, 6, 4]
        )
        // Steady-week variant
        WeeklyPulseSection(dailyDelayDays: [0, 0, 0, 0, 0, 0, 0])
    }
    .padding()
    .background(AppColors.softSurfaceLight)
    .preferredColorScheme(.light)
}

#Preview("Weekly Pulse Dark") {
    VStack {
        WeeklyPulseSection(
            dailyDelayDays: [4, 1, 2, 0, 6, 3, 7],
            previousDailyDelayDays: [1, 0, 1, 0, 2, 1, 1]
        )
    }
    .padding()
    .background(AppColors.softSurfaceDark)
    .preferredColorScheme(.dark)
}
