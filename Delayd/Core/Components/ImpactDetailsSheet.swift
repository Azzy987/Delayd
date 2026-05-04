import SwiftUI

struct ImpactDetailsSheet: View {
    let impact: HistoryImpact
    var onEdit: (() -> Void)?
    var onDelete: () -> Void = {}

    @State private var isDeleteConfirmationPresented = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                consequenceCard
                detailRows
                actions
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
        .confirmationDialog(
            "Delete this impact?",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Impact", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the logged spend and its delay from your dream timeline.")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: impact.expenseIconSystemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(impact.category.accentColor)
                .frame(width: 50, height: 50)
                .background(
                    impact.category.backgroundColor.opacity(colorScheme == .dark ? 0.22 : 1),
                    in: RoundedRectangle(cornerRadius: AppRadius.lg)
                )

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(impact.merchantName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(impact.amountText)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.negative)
            }
        }
    }

    private var consequenceCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Delayed your dream by")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            Text(impact.delayText)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.negative)

            Text(repeatingImpactText)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private var detailRows: some View {
        VStack(spacing: AppSpacing.sm) {
            detailRow("Goal affected", value: impact.goalName.delaydGoalTitleCased, icon: "target")
            detailRow("Date logged", value: impact.occurredAt.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
            detailRow("Impact type", value: "Dream delay", icon: "clock.arrow.circlepath")
        }
    }

    private func detailRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.purplePrimary)
                .frame(width: 38, height: 38)
                .background(AppColors.softPurpleBackground.opacity(colorScheme == .dark ? 0.22 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                Text(value)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            ShareLink(item: shareText) {
                actionRow(title: "Share impact", systemImage: "square.and.arrow.up", tint: AppColors.purplePrimary)
            }
            .buttonStyle(.plain)

            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    actionRow(title: "Edit", systemImage: "pencil", tint: AppColors.textPrimary(for: colorScheme))
                }
                .buttonStyle(.plain)
            }

            Button(role: .destructive) {
                isDeleteConfirmationPresented = true
            } label: {
                actionRow(title: "Delete", systemImage: "trash", tint: AppColors.negative)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionRow(title: String, systemImage: String, tint: Color) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(AppTypography.bodyMedium)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.textTertiary(for: colorScheme))
        }
        .foregroundStyle(tint)
        .padding(AppSpacing.md)
        .background(AppColors.card(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
        }
    }

    private var repeatingImpactText: String {
        let monthlyDelay = max(1, impact.delayDays) * 4
        return "Repeating this weekly would delay \(impact.goalName.delaydGoalTitleCased) by \(monthlyDelay) \(monthlyDelay == 1 ? "day" : "days")/month."
    }

    private var shareText: String {
        "\(impact.merchantName) moved \(impact.goalName.delaydGoalTitleCased) back by \(impact.delayText) in Delayd.\n\nGet Delayd: \(AppShare.appLink)"
    }
}

#Preview("Impact Details Light") {
    ImpactDetailsSheet(
        impact: HistoryImpact(
            category: .vehicle,
            expenseIconSystemImage: "cup.and.saucer.fill",
            merchantName: "Blue Tokai Coffee",
            goalName: "New car",
            delayText: "2 days",
            amountText: "-₹500",
            delayDays: 2
        )
    )
    .preferredColorScheme(.light)
}

#Preview("Impact Details Dark") {
    ImpactDetailsSheet(
        impact: HistoryImpact(
            category: .travel,
            expenseIconSystemImage: "airplane",
            merchantName: "Weekend flight upgrade",
            goalName: "Bali trip",
            delayText: "6 days",
            amountText: "-₹8,400",
            delayDays: 6
        )
    )
    .preferredColorScheme(.dark)
}
