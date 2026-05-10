import SwiftUI
import UIKit

enum AppShare {
    // Replace with the final App Store product URL once the app record exists.
    static let appLink = "https://apps.apple.com/app/delayd"

    static func goalText(_ goal: PlanGoal) -> String {
        "\(goal.displayName) is \(goal.percentageText) protected in Delayd. Every expense shows how many days it moves this dream.\n\nGet Delayd: \(appLink)"
    }

    static func profileText(goalsProtected: Int) -> String {
        let dreamWord = goalsProtected == 1 ? "dream" : "dreams"
        return "I'm protecting \(max(goalsProtected, 1)) \(dreamWord) with Delayd. Every expense shows how many days it moves my goals.\n\nGet Delayd: \(appLink)"
    }

    @MainActor
    static func progressCardImage(
        title: String,
        subtitle: String,
        amount: String,
        progressText: String,
        progress: Double,
        category: GoalCategory
    ) -> UIImage? {
        let view = ShareProgressCard(
            title: title,
            subtitle: subtitle,
            amount: amount,
            progressText: progressText,
            progress: progress,
            category: category
        )
        .frame(width: 1080, height: 1350)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1

        return renderer.uiImage
    }

    @MainActor
    static func progressCardURL(
        title: String,
        subtitle: String,
        amount: String,
        progressText: String,
        progress: Double,
        category: GoalCategory
    ) -> URL? {
        guard let image = progressCardImage(
            title: title,
            subtitle: subtitle,
            amount: amount,
            progressText: progressText,
            progress: progress,
            category: category
        ),
        let data = image.pngData() else {
            return nil
        }

        let safeTitle = title
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let fileName = "delayd-\(safeTitle.isEmpty ? "progress" : safeTitle).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

struct DelaydShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Reliable activity-sheet presenter for SwiftUI.
/// Presents `UIActivityViewController` from an inert host controller instead
/// of placing it inside a SwiftUI `.sheet`, which can render blank on some
/// simulator/runtime combinations.
struct DelaydActivityPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let items: [Any]

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard isPresented, uiViewController.presentedViewController == nil else { return }
        guard !items.isEmpty else {
            DispatchQueue.main.async { isPresented = false }
            return
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async {
                isPresented = false
            }
        }
        uiViewController.present(controller, animated: true)
    }
}

private struct ShareProgressCard: View {
    let title: String
    let subtitle: String
    let amount: String
    let progressText: String
    let progress: Double
    let category: GoalCategory

    var body: some View {
        ZStack {
            AppColors.backgroundLight

            VStack(alignment: .leading, spacing: 46) {
                HStack(spacing: 22) {
                    GoalCategoryIcon(category: category, size: 110, style: .standard)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Delayd")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(AppColors.purplePrimary)

                        Text("Dream progress")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondaryLight)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 18) {
                    Text(title)
                        .font(.system(size: 74, weight: .bold))
                        .foregroundStyle(AppColors.textPrimaryLight)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text(subtitle)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(AppColors.textSecondaryLight)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }

                VStack(alignment: .leading, spacing: 26) {
                    Text(amount)
                        .font(.system(size: 82, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.textPrimaryLight)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    GeometryReader { proxy in
                        let safeProgress = LayoutGuard.unit(progress, name: "ShareProgressCard.progress")
                        let safeWidth = LayoutGuard.dimension(proxy.size.width * safeProgress, name: "ShareProgressCard.progressWidth")
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.softPurpleBackground)

                            Capsule()
                                .fill(AppGradients.heroGradient)
                                .frame(width: safeWidth)
                        }
                    }
                    .frame(height: 26)

                    HStack {
                        Text(progressText)
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppColors.purplePrimary)

                        Spacer()

                        Text("Protected with Delayd")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondaryLight)
                    }
                }
                .padding(42)
                .background(AppColors.surfaceLight, in: RoundedRectangle(cornerRadius: 42, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 42, style: .continuous)
                        .stroke(AppColors.borderLight, lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.08), radius: 28, x: 0, y: 14)

                Spacer()

                Text("Every spend shows the days it moves your dream.")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondaryLight)
            }
            .padding(78)
        }
    }
}
