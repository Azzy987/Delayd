import SwiftUI
import Lottie

/// A SwiftUI wrapper for Lottie animations used in onboarding screens.
/// Plays the animation in a continuous loop by default with a gentle
/// floating vertical motion to keep the screen feeling alive.
struct LottieAnimationView: View {
    let animationName: String
    let loopMode: LottieLoopMode
    let size: CGFloat

    @State private var isFloating = false

    init(_ animationName: String, size: CGFloat = 220, loopMode: LottieLoopMode = .loop) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.size = size
    }

    var body: some View {
        LottieView(animation: .named(animationName))
            .playing(loopMode: loopMode)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
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

/// Full-screen Lottie overlay for confetti, celebrations, etc.
/// Plays once and auto-dismisses. Uses a fixed GeometryReader approach
/// to avoid affecting the layout of sibling views.
struct LottieOverlay: View {
    let animationName: String
    @Binding var isPlaying: Bool

    var body: some View {
        GeometryReader { proxy in
            LottieView(animation: .named(animationName))
                .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isPlaying = false
                }
            }
        }
    }
}

#Preview("Beach") {
    ZStack {
        AppGradients.heroGradient.ignoresSafeArea()
        LottieAnimationView("LottieWelcome")
    }
}

#Preview("Money") {
    ZStack {
        AppGradients.heroGradient.ignoresSafeArea()
        LottieAnimationView("LottieInsight", size: 200)
    }
}
