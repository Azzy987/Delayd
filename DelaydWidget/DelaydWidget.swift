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
    let progress: Double  // 0…1
    let daysDelayed: Int
    let savedAmount: Double
    let currencySymbol: String

    static let placeholder = DelaydWidgetEntry(
        date: .now,
        goalName: "Bali trip",
        goalEmoji: "🏝️",
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

private struct SmallWidgetView: View {
    let entry: DelaydWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(entry.goalEmoji)
                    .font(.system(size: 18))
                Text(entry.goalName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)

            Spacer(minLength: 0)

            Text("\(entry.daysDelayed)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(.white)

            Text("days delayed")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)

            WidgetProgressBar(progress: entry.progress)

            Text("\(entry.currencySymbol)\(Int(entry.savedAmount)) protected")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .widgetURL(URL(string: "delayd://history"))
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
    }
}

private struct MediumWidgetView: View {
    let entry: DelaydWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(entry.goalEmoji).font(.system(size: 20))
                    Text(entry.goalName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)

                Text("Trip delayed by")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))

                Text("\(entry.daysDelayed) day\(entry.daysDelayed == 1 ? "" : "s")")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text("\(entry.currencySymbol)\(Int(entry.savedAmount)) protected toward this dream")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            VStack(spacing: 8) {
                Gauge(value: entry.progress) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.white)

                Text("\(Int((entry.progress * 100).rounded()))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(width: 72)
        }
        .padding(14)
        .widgetURL(URL(string: "delayd://history"))
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
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
