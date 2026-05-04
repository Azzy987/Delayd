import SwiftUI

/// Subtle reusable brand texture for purple hero surfaces.
/// Keep this decorative only; foreground content should remain the hierarchy.
struct BrandPatternLayer: View {
    var foreground: Color = .white
    var strength: Double = 1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                Circle()
                    .fill(foreground.opacity(0.075 * strength))
                    .frame(width: 180, height: 180)
                    .position(x: width * 0.08, y: height * 0.12)

                Circle()
                    .fill(foreground.opacity(0.055 * strength))
                    .frame(width: 120, height: 120)
                    .position(x: width * 0.92, y: height * 0.18)

                Circle()
                    .fill(foreground.opacity(0.05 * strength))
                    .frame(width: 84, height: 84)
                    .position(x: width * 0.78, y: height * 0.78)

                BrandSparkleShape(points: 4, innerRatio: 0.20)
                    .fill(patternGradient(opacity: 0.24 * strength))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(18))
                    .position(x: width * 0.80, y: height * 0.35)

                BrandSparkleShape(points: 8, innerRatio: 0.22)
                    .fill(patternGradient(opacity: 0.17 * strength))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(8))
                    .position(x: width * 0.19, y: height * 0.68)

                BrandSparkleShape(points: 6, innerRatio: 0.30)
                    .fill(patternGradient(opacity: 0.14 * strength))
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(-15))
                    .position(x: width * 0.56, y: height * 0.16)
            }
            .frame(width: width, height: height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func patternGradient(opacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                foreground.opacity(opacity),
                foreground.opacity(opacity * 0.28)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct BrandSparkleShape: Shape {
    let points: Int
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let pointCount = max(points, 3)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * min(max(innerRatio, 0.08), 0.8)
        let totalVertices = pointCount * 2
        var path = Path()

        for index in 0..<totalVertices {
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = CGFloat(index) / CGFloat(totalVertices) * .pi * 2 - .pi / 2
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

#Preview("Brand Pattern") {
    RoundedRectangle(cornerRadius: AppRadius.xl)
        .fill(AppGradients.heroGradient)
        .overlay {
            BrandPatternLayer(strength: 1)
        }
        .frame(height: 220)
        .padding(AppSpacing.lg)
        .background(AppColors.backgroundLight)
}
