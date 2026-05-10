import SwiftUI

/// Custom-symbol wrapper for Phosphor icons stored in Assets.xcassets.
///
/// We pull individual SVGs from Phosphor's open-source `core` repo (Bold
/// weight) and drop them into the asset catalog as Image Sets with
/// `preserves-vector-representation = true` and
/// `template-rendering-intent = "template"`. That lets SwiftUI tint them
/// with `.foregroundStyle(...)` exactly like SF Symbols, while keeping
/// strokes crisp at every scale.
///
/// Why custom assets instead of an SPM icon library:
/// - No mature SwiftUI Phosphor package exists today (the few community
///   attempts are abandoned / 0–1 stars).
/// - Asset-catalog symbols are the path Apple itself recommends for
///   non-system icon sets (WWDC "Create custom symbols").
/// - Zero runtime dependency, ~30–50 KB total binary cost for 12 icons.
struct PhosphorIcon: View {
    enum Name: String {
        case house = "ic_house"
        case homeOutline = "ic_home_outline"
        case homeFilledCustom = "ic_home_filled_custom"
        case wallet = "ic_wallet"
        case goalOutline = "ic_goal_outline"
        case goalFilledCustom = "ic_goal_filled_custom"
        case chartBar = "ic_chart_bar"
        case chartBarOutline = "ic_chart_bar_outline"
        case target = "ic_target"
        case clock = "ic_clock"
        case gearSix = "ic_gear_six"
        case plus = "ic_plus"
        case arrowLeft = "ic_arrow_left"
        case arrowUpRight = "ic_arrow_up_right"
        case dotsThreeVertical = "ic_dots_three_vertical"
        case info = "ic_info"
        case bell = "ic_bell"
        case calendarBlank = "ic_calendar_blank"
        case paintBrush = "ic_paint_brush"
    }

    let name: Name
    let size: CGFloat

    init(_ name: Name, size: CGFloat = 22) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image(name.rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

#Preview("Phosphor Icons") {
    let names: [PhosphorIcon.Name] = [
        .house, .target, .clock, .gearSix,
        .plus, .arrowLeft, .arrowUpRight, .dotsThreeVertical,
        .info, .bell, .calendarBlank, .paintBrush
    ]
    return LazyVGrid(columns: Array(repeating: GridItem(), count: 4), spacing: 24) {
        ForEach(names, id: \.self) { name in
            VStack(spacing: 6) {
                PhosphorIcon(name, size: 32)
                    .foregroundStyle(.purple)
                Text(name.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding()
}
