import SwiftUI

struct SecondaryButton: View {
    let title: String
    let systemImage: String?
    let isLoading: Bool
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, isLoading: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                if isLoading {
                    ProgressView()
                } else if let systemImage {
                    Image(systemName: systemImage)
                }

                Text(title)
            }
        }
        .buttonStyle(SecondaryButtonStyle())
        .disabled(isLoading)
        .opacity(isLoading ? 0.86 : 1)
    }
}

extension SecondaryButton {
    static func mock() -> SecondaryButton {
        SecondaryButton("Review impact", systemImage: "clock.fill")
    }
}

#Preview("Default") {
    SecondaryButton.mock()
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}

#Preview("Edge Case") {
    SecondaryButton("Loading the longest review action", isLoading: true)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    SecondaryButton.mock()
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundDark)
        .preferredColorScheme(.dark)
}
