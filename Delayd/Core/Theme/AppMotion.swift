import SwiftUI

enum AppMotion {
    // MARK: - Durations

    static let forwardProgressDuration: TimeInterval = 0.28
    static let backwardProgressDuration: TimeInterval = 0.60
    static let cardTransitionResponse: Double = 0.50
    static let cardTransitionDamping: Double = 0.85
    static let sheetPresentationResponse: Double = 0.40
    static let sheetPresentationDamping: Double = 0.80

    // MARK: - Animations

    /// Forward progress: optimistic, light, fast.
    /// Use for: goals being achieved, savings added, positive deltas.
    static let forwardProgress = Animation.easeOut(duration: forwardProgressDuration)

    /// Backward progress: deliberate, slow, weighty.
    /// Use for: delay impacts, lost time, negative deltas.
    /// Intentionally slower than forward — the delay should FEEL.
    static let backwardProgress = Animation.easeInOut(duration: backwardProgressDuration)
    static let cardTransition = Animation.spring(response: cardTransitionResponse, dampingFraction: cardTransitionDamping)
    static let sheetPresentation = Animation.spring(response: sheetPresentationResponse, dampingFraction: sheetPresentationDamping)
    static let pressFeedback = Animation.spring(response: 0.22, dampingFraction: 0.85)

    // MARK: - Press Scale

    static let buttonPressScale: CGFloat = 0.97
    static let floatingButtonPressScale: CGFloat = 0.92
}

private struct AppMotionPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var delayed = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Backward progress")
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.softNegativeBackground)
                    Capsule()
                        .fill(AppColors.negative)
                        .frame(width: proxy.size.width * (delayed ? 0.38 : 0.74))
                }
            }
            .frame(height: 12)

            Button(delayed ? "Reset" : "Delay impact") {
                withAnimation(AppMotion.backwardProgress) {
                    delayed.toggle()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.purplePrimary)
        }
        .padding(AppSpacing.lg)
        .background(AppColors.background(for: colorScheme))
    }
}

#Preview("App Motion Light") {
    AppMotionPreview()
        .preferredColorScheme(.light)
}

#Preview("App Motion Dark") {
    AppMotionPreview()
        .preferredColorScheme(.dark)
}
