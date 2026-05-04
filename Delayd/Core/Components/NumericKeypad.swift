import SwiftUI

struct NumericKeypad: View {
    @Binding var text: String
    var maxIntegerDigits: Int = 9
    var maxFractionDigits: Int = 2
    var keyHeight: CGFloat = 52
    var keySpacing: CGFloat = 10
    var horizontalPadding: CGFloat = AppSpacing.md
    var verticalPadding: CGFloat = AppSpacing.md
    var digitFontSize: CGFloat = 26
    var showsBackground: Bool = true
    var onKeyTap: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: keySpacing),
            GridItem(.flexible(), spacing: keySpacing),
            GridItem(.flexible(), spacing: keySpacing)
        ]
    }

    private enum Key: Hashable {
        case digit(String)
        case dot
        case backspace
    }

    private let keys: [Key] = [
        .digit("1"), .digit("2"), .digit("3"),
        .digit("4"), .digit("5"), .digit("6"),
        .digit("7"), .digit("8"), .digit("9"),
        .dot, .digit("0"), .backspace
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: keySpacing) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                keyButton(key)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, verticalPadding)
        .padding(.bottom, AppSpacing.xs)
        .background(keypadBackground)
    }

    @ViewBuilder
    private var keypadBackground: some View {
        if showsBackground {
            // Bottom-sheet shape: only the top corners round so the keypad
            // visually attaches to the screen edge while floating above the
            // form content.
            UnevenRoundedRectangle(
                topLeadingRadius: 24, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 24,
                style: .continuous
            )
            .fill(AppColors.surface(for: colorScheme))
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private func keyButton(_ key: Key) -> some View {
        Button {
            handleTap(key)
        } label: {
            keyLabel(key)
                .frame(maxWidth: .infinity)
                .frame(height: keyHeight)
                .background(
                    AppColors.softSurface(for: colorScheme),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
        .buttonStyle(KeypadButtonStyle())
        .accessibilityLabel(accessibilityLabel(for: key))
    }

    @ViewBuilder
    private func keyLabel(_ key: Key) -> some View {
        switch key {
        case .digit(let value):
            Text(value)
                .font(.system(size: digitFontSize, weight: .bold, design: .default))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
        case .dot:
            Text("·")
                .font(.system(size: digitFontSize + 10, weight: .black, design: .default))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .baselineOffset(-6)
        case .backspace:
            Image(systemName: "delete.left.fill")
                .font(.system(size: max(17, digitFontSize - 6), weight: .semibold))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
        }
    }

    private func accessibilityLabel(for key: Key) -> String {
        switch key {
        case .digit(let value): value
        case .dot: "decimal point"
        case .backspace: "delete"
        }
    }

    private func handleTap(_ key: Key) {
        onKeyTap?()
        switch key {
        case .digit(let value):
            appendDigit(value)
        case .dot:
            appendDot()
        case .backspace:
            backspace()
        }
    }

    private func appendDigit(_ digit: String) {
        if text == "0" {
            text = digit
            return
        }

        if let dotIndex = text.firstIndex(of: ".") {
            let fractionCount = text.distance(from: text.index(after: dotIndex), to: text.endIndex)
            if fractionCount >= maxFractionDigits { return }
        } else {
            if text.count >= maxIntegerDigits { return }
        }

        text.append(digit)
    }

    private func appendDot() {
        if text.isEmpty {
            text = "0."
            return
        }
        if text.contains(".") { return }
        text.append(".")
    }

    private func backspace() {
        guard !text.isEmpty else { return }
        text.removeLast()
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct NumericKeypadPreview: View {
    @State private var text = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 24) {
            Text(text.isEmpty ? "0" : text)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            NumericKeypad(text: $text)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
    }
}

#Preview("Numeric Keypad") {
    NumericKeypadPreview()
}

#Preview("Numeric Keypad Dark") {
    NumericKeypadPreview()
        .preferredColorScheme(.dark)
}
