import SwiftUI

struct FloatingActionButton: View {
    let systemImage: String
    let phosphorIcon: PhosphorIcon.Name?
    let action: () -> Void

    init(systemImage: String = "plus", action: @escaping () -> Void = {}) {
        self.systemImage = systemImage
        self.phosphorIcon = nil
        self.action = action
    }

    init(phosphor: PhosphorIcon.Name, action: @escaping () -> Void = {}) {
        self.systemImage = ""
        self.phosphorIcon = phosphor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let phosphorIcon {
                PhosphorIcon(phosphorIcon, size: 24)
            } else {
                Image(systemName: systemImage)
            }
        }
        .buttonStyle(FloatingActionButtonStyle())
        .accessibilityLabel("Log impact")
    }
}

extension FloatingActionButton {
    static func mock() -> FloatingActionButton {
        FloatingActionButton()
    }
}

#Preview("Default") {
    FloatingActionButton.mock()
        .padding(AppSpacing.xl)
        .background(AppColors.backgroundLight)
}

#Preview("Edge Case") {
    HStack(spacing: AppSpacing.xl) {
        FloatingActionButton(systemImage: "plus")
        FloatingActionButton(systemImage: "target")
        FloatingActionButton(systemImage: "clock.fill")
    }
    .padding(AppSpacing.xl)
    .background(AppColors.backgroundLight)
}

#Preview("Dark") {
    FloatingActionButton.mock()
        .padding(AppSpacing.xl)
        .background(AppColors.backgroundDark)
        .preferredColorScheme(.dark)
}
