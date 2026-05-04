import SwiftUI

struct TagChip: View {
    let text: String
    let variant: Variant
    let showsDismiss: Bool
    let onDismiss: (() -> Void)?

    init(_ text: String, variant: Variant = .purple, showsDismiss: Bool = false, onDismiss: (() -> Void)? = nil) {
        self.text = text
        self.variant = variant
        self.showsDismiss = showsDismiss
        self.onDismiss = onDismiss
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Text(text)
                .font(AppTypography.captionMedium)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if showsDismiss {
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(variant.foregroundColor(for: colorScheme))
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            variant.backgroundColor.opacity(colorScheme == .dark ? 0.25 : 1),
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
    }
}

extension TagChip {
    enum Variant {
        case purple
        case warning
        case positive

        func foregroundColor(for colorScheme: ColorScheme) -> Color {
            if colorScheme == .dark {
                switch self {
                case .purple:  AppColors.heroGradientStart        // bright violet
                case .warning: AppColors.warning                  // bright amber
                case .positive: AppColors.positive                // bright green
                }
            } else {
                switch self {
                case .purple:  Color(red: 0.40, green: 0.24, blue: 0.86)
                case .warning: Color(red: 0.72, green: 0.36, blue: 0.10)
                case .positive: Color(red: 0.10, green: 0.48, blue: 0.30)
                }
            }
        }

        var backgroundColor: Color {
            switch self {
            case .purple: AppColors.softPurpleBackground
            case .warning: Color(red: 1.0, green: 0.90, blue: 0.82)
            case .positive: Color(red: 0.85, green: 0.96, blue: 0.89)
            }
        }
    }

    static func mock() -> TagChip {
        TagChip("Vacation", variant: .purple)
    }
}

private struct TagChipPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            TagChip("My Hobby", variant: .purple, showsDismiss: true)
            TagChip("Vacation", variant: .warning)
            TagChip("On pace", variant: .positive)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    TagChipPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    TagChip("A very long filter chip label", variant: .purple, showsDismiss: true)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    TagChipPreviewGroup()
        .preferredColorScheme(.dark)
}
