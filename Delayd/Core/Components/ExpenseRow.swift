import SwiftUI

struct ExpenseRow: View {
    let category: GoalCategory
    var expenseIconSystemImage = "creditcard.fill"
    let merchantName: String
    let goalName: String
    let delayText: String
    let amountText: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = iconPalette

        HStack(spacing: AppSpacing.md) {
            Image(systemName: expenseIconSystemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.tint)
                .frame(width: 40, height: 40)
                .background(
                    palette.background.opacity(colorScheme == .dark ? 0.18 : 1),
                    in: RoundedRectangle(cornerRadius: AppRadius.md)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(palette.tint.opacity(colorScheme == .dark ? 0.24 : 0.14), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(merchantName)
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .lineLimit(1)

                Text("Delayed \(goalName.delaydGoalTitleCased) by \(delayText)")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                    .lineLimit(2)
            }

            Spacer(minLength: AppSpacing.sm)

            Text(amountText)
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var iconPalette: (tint: Color, background: Color) {
        let label = expenseIconSystemImage.lowercased()
        if label.contains("cup") {
            return (Color(red: 0.72, green: 0.36, blue: 0.10), Color(red: 1.0, green: 0.92, blue: 0.84))
        }
        if label.contains("fork") {
            return (AppColors.travelAccent, AppColors.travelBackground)
        }
        if label.contains("bag") {
            return (AppColors.homeAccent, AppColors.homeBackground)
        }
        if label.contains("car") || label.contains("airplane") {
            return (AppColors.vehicleAccent, AppColors.vehicleBackground)
        }
        if label.contains("cross") {
            return (AppColors.positive, AppColors.softPositiveBackground)
        }
        if label.contains("popcorn") || label.contains("headphones") {
            return (AppColors.techAccent, AppColors.techBackground)
        }
        if label.contains("book") {
            return (AppColors.educationAccent, AppColors.educationBackground)
        }
        return (category.accentColor, category.backgroundColor)
    }
}

extension ExpenseRow {
    static func mock() -> ExpenseRow {
        ExpenseRow(
            category: .travel,
            merchantName: "Blue Tokai Coffee",
            goalName: "Bali trip",
            delayText: "2 days",
            amountText: "-₹500"
        )
    }

    static func mockEdgeCase() -> ExpenseRow {
        ExpenseRow(
            category: .education,
            merchantName: "A very long merchant name that should not break the row layout",
            goalName: "Postgraduate degree and relocation fund",
            delayText: "12 days",
            amountText: "-₹12,345"
        )
    }
}

private struct ExpenseRowPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ExpenseRow.mock()
            Divider()
            ExpenseRow(category: .savings, merchantName: "Movie night", goalName: "Emergency fund", delayText: "6 hours", amountText: "-₹249")
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    ExpenseRowPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    ExpenseRow.mockEdgeCase()
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    ExpenseRowPreviewGroup()
        .preferredColorScheme(.dark)
}
