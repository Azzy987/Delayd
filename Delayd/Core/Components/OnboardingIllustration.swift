import SwiftUI

/// Reusable onboarding illustration with a gentle floating animation.
/// Clips the image to a circle to hide the white PNG background and
/// applies a subtle up-down float to make the screen feel alive.
struct OnboardingIllustration: View {
    let imageName: String
    let size: CGFloat

    @State private var isFloating = false

    init(_ imageName: String, size: CGFloat = 220) {
        self.imageName = imageName
        self.size = size
    }

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
            .offset(y: isFloating ? -6 : 4)
            .animation(
                .easeInOut(duration: 2.8)
                .repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear { isFloating = true }
            .accessibilityHidden(true)
    }
}

#Preview("Light") {
    ZStack {
        AppGradients.heroGradient
            .ignoresSafeArea()

        OnboardingIllustration("OnboardingReady")
    }
}

#Preview("Dark") {
    ZStack {
        AppColors.backgroundDark
            .ignoresSafeArea()

        OnboardingIllustration("OnboardingTone", size: 200)
    }
    .preferredColorScheme(.dark)
}
