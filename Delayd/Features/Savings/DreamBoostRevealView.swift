import SwiftUI

struct DreamBoostRevealView: View {
    let impact: DreamBoostImpact
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var animatedProgress = 0.0
    @State private var showContent = false

    var body: some View {
        ZStack {
            AppColors.background(for: colorScheme)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.xl) {
                Spacer(minLength: AppSpacing.xl)

                VStack(spacing: AppSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(AppColors.softPositiveBackground.opacity(colorScheme == .dark ? 0.18 : 1))
                            .frame(width: 112, height: 112)

                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(AppColors.positive)
                    }

                    Text("Dream protected")
                        .font(.system(size: 30, weight: .bold, design: .default))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                    Text(headline)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.positive)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.68)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 14)

                VStack(spacing: AppSpacing.md) {
                    progressMeter

                    VStack(spacing: AppSpacing.sm) {
                        Text(timelineLine)
                            .font(AppTypography.bodyMedium)
                            .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(nudgeLine)
                            .font(AppTypography.callout)
                            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .delaydCard()
                .padding(.horizontal, AppSpacing.lg)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 18)

                Spacer()

                PrimaryButton("Done", action: onDismiss)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
                    .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(AppMotion.forwardProgress.delay(0.1)) {
                animatedProgress = impact.newProgress
            }
            withAnimation(.spring(response: 0.46, dampingFraction: 0.82).delay(0.08)) {
                showContent = true
            }
        }
    }

    private var progressMeter: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Protected")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                Spacer()

                Text("\(Int((impact.newProgress * 100).rounded()))%")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.positive)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.border(for: colorScheme))

                    Capsule()
                        .fill(AppColors.positive)
                        .frame(width: proxy.size.width * min(max(animatedProgress, 0), 1))
                }
            }
            .frame(height: 10)

            HStack {
                Text(CurrencyFormatter.format(impact.newAmount, currencyCode: impact.currencyCode))
                Spacer()
                Text(CurrencyFormatter.format(impact.affectedGoal.targetAmount, currencyCode: impact.currencyCode))
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textSecondary(for: colorScheme))
        }
    }

    private var headline: String {
        let dayWord = impact.daysCloser == 1 ? "day" : "days"
        return "\(impact.daysCloser) \(dayWord) closer"
    }

    private var timelineLine: String {
        guard let previous = impact.previousTargetDate, let improved = impact.improvedTargetDate else {
            return "\(CurrencyFormatter.format(impact.amount, currencyCode: impact.currencyCode)) is now protected in \(impact.location.title.lowercased())."
        }
        return "You moved \(impact.affectedGoal.name.delaydGoalTitleCased) to \(formattedDate(improved)) instead of \(formattedDate(previous))."
    }

    private var nudgeLine: String {
        let remaining = max(impact.affectedGoal.targetAmount - impact.newAmount, 0)
        guard remaining > 0 else {
            return "Goal fully protected. Keep it untouched."
        }

        if let targetDate = impact.previousTargetDate {
            let today = Calendar.current.startOfDay(for: .now)
            let targetDay = Calendar.current.startOfDay(for: targetDate)
            let daysRemaining = max(1, Calendar.current.dateComponents([.day], from: today, to: targetDay).day ?? 1)
            let dailyNeeded = ceil(remaining / Double(daysRemaining))
            return "You are \(CurrencyFormatter.format(remaining, currencyCode: impact.currencyCode)) away. Protect \(CurrencyFormatter.format(dailyNeeded, currencyCode: impact.currencyCode))/day to hit \(formattedDate(targetDate))."
        }

        let monthlyPace = max(1, ceil(remaining / 6))
        return "You are \(CurrencyFormatter.format(remaining, currencyCode: impact.currencyCode)) away. Protect \(CurrencyFormatter.format(monthlyPace, currencyCode: impact.currencyCode))/month and momentum stays visible."
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }
}

#Preview("Boost Reveal Light") {
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
            currencyCode: "USD",
            previousTargetDate: Calendar.current.date(byAdding: .month, value: 8, to: .now),
            improvedTargetDate: Calendar.current.date(byAdding: .day, value: 15, to: Calendar.current.date(byAdding: .month, value: 7, to: .now) ?? .now)
        ),
        onDismiss: {}
    )
    .preferredColorScheme(.light)
}
