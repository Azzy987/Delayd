import SwiftUI

struct BrandLogoView: View {
    let size: Size

    init(size: Size = .medium) {
        self.size = size
    }

    var body: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size.dimension, height: size.dimension)
            .accessibilityLabel("Delayd")
    }
}

extension BrandLogoView {
    enum Size: CGFloat, CaseIterable, Identifiable {
        case small = 24
        case medium = 40
        case large = 64
        case icon = 96

        var id: CGFloat { rawValue }
        var dimension: CGFloat { rawValue }
        var label: String {
            switch self {
            case .small: "Small"
            case .medium: "Medium"
            case .large: "Large"
            case .icon: "Icon"
            }
        }
    }
}

private struct BrandLogoPreviewGroup: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.lg) {
            ForEach(BrandLogoView.Size.allCases) { size in
                VStack(spacing: AppSpacing.sm) {
                    BrandLogoView(size: size)
                    Text(size.label)
                        .font(AppTypography.captionMedium)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("Default") {
    BrandLogoPreviewGroup()
        .preferredColorScheme(.light)
}

#Preview("Edge Case") {
    VStack(spacing: AppSpacing.xl) {
        BrandLogoView(size: .icon)
        Text("Large icon source scaled down cleanly from Assets.xcassets")
            .font(AppTypography.body)
            .multilineTextAlignment(.center)
    }
    .padding(AppSpacing.xl)
    .background(AppColors.backgroundLight)
}

#Preview("Dark") {
    BrandLogoPreviewGroup()
        .preferredColorScheme(.dark)
}
