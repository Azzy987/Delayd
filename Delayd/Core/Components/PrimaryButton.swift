import SwiftUI

struct PrimaryButton: View {
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
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }

                Text(title)
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isLoading)
        .opacity(isLoading ? 0.86 : 1)
    }
}

extension PrimaryButton {
    static func mock() -> PrimaryButton {
        PrimaryButton("Protect dream", systemImage: "lock.fill")
    }
}

#Preview("Default") {
    PrimaryButton.mock()
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}

#Preview("Edge Case") {
    PrimaryButton("Creating a very long dream protection action", isLoading: true)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
        .dynamicTypeSize(.accessibility2)
}

#Preview("Dark") {
    PrimaryButton.mock()
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundDark)
        .preferredColorScheme(.dark)
}
