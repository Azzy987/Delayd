import SwiftUI

enum AppGradients {
    // MARK: - Hero

    static let heroGradient = LinearGradient(
        stops: [
            .init(color: Color(red: 0.62, green: 0.50, blue: 1.00), location: 0.0),
            .init(color: Color(red: 0.49, green: 0.32, blue: 0.92), location: 0.55),
            .init(color: Color(red: 0.36, green: 0.20, blue: 0.78), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let heroGradientAngle = Angle.degrees(135)
}

private struct AppGradientsPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Hero Gradient")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            RoundedRectangle(cornerRadius: AppRadius.xl)
                .fill(AppGradients.heroGradient)
                .frame(height: 160)
                .shadow(
                    color: AppShadows.heroCardLight.color,
                    radius: AppShadows.heroCardLight.blur,
                    x: AppShadows.heroCardLight.x,
                    y: AppShadows.heroCardLight.y
                )
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("App Gradients Light") {
    AppGradientsPreview()
        .preferredColorScheme(.light)
}

#Preview("App Gradients Dark") {
    AppGradientsPreview()
        .preferredColorScheme(.dark)
}
