import SwiftUI

struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .lineLimit(2)

            Spacer(minLength: AppSpacing.md)

            if let actionTitle {
                Button(actionTitle) {
                    action?()
                }
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.purplePrimary)
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension SectionHeader {
    static func mock() -> SectionHeader {
        SectionHeader("Recent impacts", actionTitle: "View All")
    }
}

private struct SectionHeaderPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            SectionHeader.mock()
            SectionHeader("Smart insights")
            SectionHeader("Goals that moved this week", actionTitle: "Manage")
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    SectionHeaderPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    SectionHeader("A very long section title that may need two lines", actionTitle: "View Everything")
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    SectionHeaderPreviewGroup()
        .preferredColorScheme(.dark)
}
