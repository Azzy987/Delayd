//
// DelaydWidget.swift
// DelaydWidget (Widget Extension target)
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

/// Minimal snapshot the widget needs. Kept intentionally small because
/// widgets get tight memory budgets. The main app refreshes this snapshot in
/// shared UserDefaults whenever the default goal or its progress changes.
struct DelaydWidgetEntry: TimelineEntry {
    let date: Date
    let goalName: String
    let goalEmoji: String
    let goalIllustrationAssetName: String
    let progress: Double  // 0…1
    let daysDelayed: Int
    let savedAmount: Double
    let currencySymbol: String

    static let placeholder = DelaydWidgetEntry(
        date: .now,
        goalName: "Bali trip",
        goalEmoji: "🏝️",
        goalIllustrationAssetName: "CategoryTravel",
        progress: 0.42,
        daysDelayed: 3,
        savedAmount: 50_400,
        currencySymbol: "₹"
    )
}

// MARK: - Provider

struct DelaydWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DelaydWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DelaydWidgetEntry) -> Void) {
        completion(readSharedEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DelaydWidgetEntry>) -> Void) {
        let entry = readSharedEntry() ?? .placeholder
        // Refresh every 30 minutes — progress only moves when the user logs,
        // and the app also requests a timeline reload then via
        // WidgetCenter.shared.reloadAllTimelines().
        let timeline = Timeline(
            entries: [entry],
            policy: .after(Date.now.addingTimeInterval(30 * 60))
        )
        completion(timeline)
    }

    /// Shared App Group key. The main app writes this via `DelaydWidgetSync`.
    private func readSharedEntry() -> DelaydWidgetEntry? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.delayd.shared") != nil else {
            return nil
        }
        guard
            let defaults = UserDefaults(suiteName: "group.com.delayd.shared"),
            let data = defaults.data(forKey: "widget.entry"),
            let decoded = try? JSONDecoder().decode(DelaydWidgetEntryDTO.self, from: data)
        else { return nil }
        return decoded.toEntry()
    }
}

// MARK: - Shared DTO

/// Codable mirror of `DelaydWidgetEntry` for App Group persistence. Kept
/// separate from the TimelineEntry type so we can evolve the on-disk shape
/// without breaking the widget contract.
struct DelaydWidgetEntryDTO: Codable {
    let goalName: String
    let goalEmoji: String
    let goalIllustrationAssetName: String
    let progress: Double
    let daysDelayed: Int
    let savedAmount: Double
    let currencySymbol: String
    let writtenAt: Date

    func toEntry() -> DelaydWidgetEntry {
        DelaydWidgetEntry(
            date: writtenAt,
            goalName: goalName,
            goalEmoji: goalEmoji,
            goalIllustrationAssetName: goalIllustrationAssetName,
            progress: progress,
            daysDelayed: daysDelayed,
            savedAmount: savedAmount,
            currencySymbol: currencySymbol
        )
    }
}

// MARK: - Widget Views

struct DelaydWidgetView: View {
    let entry: DelaydWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let lock = WidgetAccessGate.currentLockState() {
            switch family {
            case .systemSmall:
                SmallLockedWidgetView(lock: lock)
            case .systemMedium:
                MediumLockedWidgetView(lock: lock)
            default:
                SmallLockedWidgetView(lock: lock)
            }
        } else {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
    }
}

private enum WidgetAccessGate {
    private static let appGroupID = "group.com.delayd.shared"
    private static let trialStartDateKey = "widget.trial.startDate"
    private static let proUnlockedKey = "widget.pro.unlocked"
    private static let trialDurationDays = 7

    struct LockState {
        let trialDaysLeft: Int
    }

    static func currentLockState(now: Date = .now) -> LockState? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) != nil else {
            return nil
        }
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        if defaults.bool(forKey: proUnlockedKey) {
            return nil
        }

        let startDate = (defaults.object(forKey: trialStartDateKey) as? Date) ?? now
        let elapsedDays = max(0, Calendar.current.dateComponents([.day], from: startDate, to: now).day ?? 0)
        let daysLeft = max(0, trialDurationDays - elapsedDays)
        return daysLeft > 0 ? nil : LockState(trialDaysLeft: daysLeft)
    }
}

private struct SmallWidgetView: View {
    let entry: DelaydWidgetEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            goalIllustration(size: 66)
                .opacity(0.94)
                .offset(x: 78, y: -54)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    goalIllustration(size: 24)
                    Text(entry.goalName)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .foregroundStyle(.white)

                Spacer(minLength: 0)

                Text("\(entry.daysDelayed) day\(entry.daysDelayed == 1 ? "" : "s")")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.56)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text("delayed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)

                WidgetProgressBar(progress: entry.progress)

                Text(protectedText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .widgetURL(URL(string: "delayd://paywall"))
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
    }

    private var protectedText: String {
        "\(entry.currencySymbol)\(Int(entry.savedAmount)) protected toward this dream"
    }
}

private struct MediumWidgetView: View {
    let entry: DelaydWidgetEntry

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    goalIllustration(size: 28)
                    Text(entry.goalName)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .foregroundStyle(.white)

                Text("Dream delayed by")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))

                Text("\(entry.daysDelayed) day\(entry.daysDelayed == 1 ? "" : "s")")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text("\(entry.currencySymbol)\(Int(entry.savedAmount)) protected toward this dream")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                WidgetProgressBar(progress: entry.progress)
                    .padding(.top, 2)
            }

            Spacer(minLength: 4)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    }

                goalIllustration(size: 96)
                    .padding(.bottom, 22)

                Text("\(progressPercent)% protected")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.24), in: Capsule())
                    .padding(.bottom, 8)
            }
            .frame(width: 112, height: 120)
        }
        .padding(14)
        .widgetURL(URL(string: "delayd://paywall"))
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
    }

    private var progressPercent: Int {
        Int((min(max(entry.progress, 0), 1) * 100).rounded())
    }
}

private struct GoalArtworkView: View {
    let imageName: String
    let size: CGFloat

    var body: some View {
        let cornerRadius = max(10, size * 0.22)

        Image(imageName)
            .resizable()
            .scaledToFit()
            .padding(max(3, size * 0.08))
            .frame(width: size, height: size)
            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 5)
    }
}

private extension SmallWidgetView {
    @ViewBuilder
    func goalIllustration(size: CGFloat) -> some View {
        GoalArtworkView(imageName: entry.goalIllustrationAssetName, size: size)
    }
}

private extension MediumWidgetView {
    @ViewBuilder
    func goalIllustration(size: CGFloat) -> some View {
        GoalArtworkView(imageName: entry.goalIllustrationAssetName, size: size)
    }
}

private struct WidgetBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 139 / 255, green: 111 / 255, blue: 255 / 255),
                    Color(red: 107 / 255, green: 71 / 255, blue: 224 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.14))
                .frame(width: 118, height: 118)
                .offset(x: 58, y: -54)

            Circle()
                .fill(.black.opacity(0.10))
                .frame(width: 150, height: 150)
                .offset(x: -82, y: 76)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: 170, height: 86)
                .rotationEffect(.degrees(-18))
                .offset(x: 88, y: 60)
        }
    }
}

private struct WidgetProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.24))

                Capsule()
                    .fill(.white)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: 6)
    }
}

private struct SmallLockedWidgetView: View {
    let lock: WidgetAccessGate.LockState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Delayd Pro")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text("Widget trial ended")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
            Spacer(minLength: 0)
            Text("Upgrade to keep this widget active")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }
        .padding(12)
        .widgetURL(URL(string: "delayd://home"))
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
    }
}

private struct MediumLockedWidgetView: View {
    let lock: WidgetAccessGate.LockState

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Delayd Pro")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Text("Widget trial ended")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                Text("Upgrade to keep this widget active")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(14)
        .widgetURL(URL(string: "delayd://home"))
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
    }
}

// MARK: - Widget Declaration

struct DelaydWidget: Widget {
    let kind: String = "DelaydWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DelaydWidgetProvider()) { entry in
            DelaydWidgetView(entry: entry)
        }
        .configurationDisplayName("Delayd")
        .description("See how many days spending has delayed your dream.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct DelaydWidgetBundle: WidgetBundle {
    var body: some Widget {
        DelaydWidget()
    }
}
