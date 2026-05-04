import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct HapticService {
    var isEnabled = true

    func playLightImpact() {
        guard isEnabled else { return }

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    func playWarning() {
        guard isEnabled else { return }

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}

#Preview("Haptic Service") {
    Text("Haptics are device-only")
        .font(AppTypography.body)
        .foregroundStyle(AppColors.textPrimaryLight)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
