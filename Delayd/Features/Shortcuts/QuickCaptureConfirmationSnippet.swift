import SwiftUI

/// SwiftUI snippet rendered inside the Shortcuts confirmation dialog when the
/// user runs `QuickCaptureExpenseIntent`. Shortcuts hosts this view in its
/// own process via the `_AppIntents_SwiftUI` bridge (iOS 16+), so we keep the
/// dependencies to plain SwiftUI / SF Symbols and avoid the app's design
/// tokens (which may not resolve in Shortcuts' rendering environment).
///
/// Layout mirrors the user-supplied screenshot: a large amount up top,
/// followed by a vertical list of icon + label + value rows.
struct QuickCaptureConfirmationSnippet: View {
    let amountText: String
    let merchant: String
    let spendType: String
    let dreamName: String
    let paymentLabel: String
    let expenseDate: Date
    let delayDays: Int

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 18) {
            Text(amountText)
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.top, 8)

            VStack(spacing: 14) {
                row(
                    icon: "text.alignleft",
                    label: "Title",
                    value: merchantLine
                )
                row(
                    icon: "tag",
                    label: "Category",
                    value: spendType
                )
                row(
                    icon: "target",
                    label: "Dream",
                    value: dreamName
                )
                row(
                    icon: "creditcard",
                    label: "Payment",
                    value: paymentLabel
                )
                row(
                    icon: "calendar",
                    label: "Date",
                    value: Self.dateFormatter.string(from: expenseDate)
                )
                row(
                    icon: "hourglass",
                    label: "Impact",
                    value: impactText,
                    valueColor: delayDays > 0 ? .orange : .green
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
    }

    private var merchantLine: String {
        merchant.isEmpty ? spendType : merchant
    }

    private var impactText: String {
        if delayDays <= 0 {
            return "On track"
        }
        return "+\(DelayTextFormatter.daysText(delayDays))"
    }

    @ViewBuilder
    private func row(
        icon: String,
        label: String,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)

            Text(label)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// SwiftUI snippet shown after the user confirms the expense. Renders a
/// simple success card with the amount and the resulting impact on the
/// active dream — much friendlier than a wall of `IntentDialog` text.
struct QuickCaptureResultSnippet: View {
    let amountText: String
    let dreamName: String
    let delayDays: Int
    let toneMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.18))
                    .frame(width: 64, height: 64)
                Image(systemName: badgeIcon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(badgeColor)
            }
            .padding(.top, 4)

            VStack(spacing: 4) {
                Text("\(amountText) logged")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    private var badgeColor: Color {
        delayDays > 0 ? .orange : .green
    }

    private var badgeIcon: String {
        delayDays > 0 ? "hourglass" : "checkmark.circle.fill"
    }

    private var subtitle: String {
        if let toneMessage, delayDays > 0 {
            return toneMessage
        }
        if delayDays > 0 {
            return "\(dreamName) pushed back by \(DelayTextFormatter.daysText(delayDays))."
        }
        return "\(dreamName) is still on track."
    }
}

#Preview("Confirmation - Light") {
    QuickCaptureConfirmationSnippet(
        amountText: "₹10.00",
        merchant: "Coffee",
        spendType: "Food & Drinks",
        dreamName: "Bali Trip",
        paymentLabel: "Cash",
        expenseDate: .now,
        delayDays: 2
    )
    .padding()
    .preferredColorScheme(.light)
}

#Preview("Confirmation - Dark") {
    QuickCaptureConfirmationSnippet(
        amountText: "₹10.00",
        merchant: "Coffee",
        spendType: "Food & Drinks",
        dreamName: "Bali Trip",
        paymentLabel: "Cash",
        expenseDate: .now,
        delayDays: 0
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Result - Delayed") {
    QuickCaptureResultSnippet(
        amountText: "₹10.00",
        dreamName: "Bali Trip",
        delayDays: 2,
        toneMessage: "That ₹10 nudged Bali Trip back by 2 days."
    )
    .padding()
}

#Preview("Result - On Track") {
    QuickCaptureResultSnippet(
        amountText: "₹10.00",
        dreamName: "Bali Trip",
        delayDays: 0,
        toneMessage: nil
    )
    .padding()
}
