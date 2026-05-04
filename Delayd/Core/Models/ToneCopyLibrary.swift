import Foundation

enum ToneCopyCategory: String, CaseIterable, Identifiable {
    case quietWeek
    case recurringSpend
    case weeklyBudget
    case goalSlipped
    case highImpact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quietWeek: "Quiet week"
        case .recurringSpend: "Recurring spend"
        case .weeklyBudget: "Weekly budget"
        case .goalSlipped: "Goal slipped"
        case .highImpact: "High impact"
        }
    }

    var usage: String {
        switch self {
        case .quietWeek: "Use when the user has little or no recent activity."
        case .recurringSpend: "Use when one merchant or tag appears repeatedly."
        case .weeklyBudget: "Use when weekly delay-days cross a meaningful threshold."
        case .goalSlipped: "Use when a goal's estimated date moves backward."
        case .highImpact: "Use after a large spend or hard-mode confirmation."
        }
    }
}

enum ToneCopyLibrary {
    static func lines(for tone: DelaydTone, category: ToneCopyCategory) -> [String] {
        switch tone {
        case .motivational:
            motivational[category] ?? []
        case .coach:
            coach[category] ?? []
        case .neutral:
            neutral[category] ?? []
        case .toughLove:
            toughLove[category] ?? []
        case .drillSergeant:
            drillSergeant[category] ?? []
        }
    }

    static func line(for tone: DelaydTone, category: ToneCopyCategory, seed: Int) -> String {
        let options = lines(for: tone, category: category)
        guard !options.isEmpty else { return tone.sampleLine }
        return options[abs(seed) % options.count]
    }

    static func totalLineCount(for tone: DelaydTone) -> Int {
        ToneCopyCategory.allCases.reduce(0) { $0 + lines(for: tone, category: $1).count }
    }

    private static let motivational: [ToneCopyCategory: [String]] = [
        .quietWeek: [
            "Quiet week so far. Your dream is getting breathing room.",
            "No big slips lately. Keep giving your goal space to move closer.",
            "A calm spending week is progress you can feel later.",
            "Your dream stayed protected today. That counts.",
            "Small restraint is still movement toward the life you want.",
            "Nothing pulled your goal back today. Hold that line.",
            "A quiet log can be a strong signal. Keep it steady.",
            "Your goal has momentum when spending stays calm.",
            "This is what protecting a dream looks like on ordinary days.",
            "No delay pressure right now. Let the goal keep moving forward."
        ],
        .recurringSpend: [
            "This pattern is visible now. One small change can win days back.",
            "Repeated spends are where gentle progress can compound fastest.",
            "You found a repeat habit. Trim it once and the dream feels closer.",
            "This is a useful signal, not a failure. Adjust and keep going.",
            "Recurring spends are perfect places to protect your goal.",
            "One recurring choice can become several saved days.",
            "You do not need perfection. Start by skipping the next repeat.",
            "A small habit shift here could give your dream real momentum.",
            "This pattern is fixable, and the upside is measured in days.",
            "Notice it, choose once, and let the goal move closer."
        ],
        .weeklyBudget: [
            "You still have room to protect the week. Spend with the dream in view.",
            "This week is not decided yet. A few clean choices can steady it.",
            "Your weekly pace is visible now. Use it to stay intentional.",
            "The goal is still within reach this week. Keep the next choice clean.",
            "You can slow the delay from here. Small course corrections count.",
            "A weekly check-in gives you control before the month drifts.",
            "You have enough information to protect the rest of the week.",
            "Keep the delay small and the dream stays emotionally close.",
            "This is a moment to reset, not to spiral.",
            "The week can still end strong."
        ],
        .goalSlipped: [
            "The goal moved back, but it is still yours to recover.",
            "A slip is information. One steady week can pull the timeline closer.",
            "Your dream took a step back. Now you know exactly how to respond.",
            "This delay is recoverable with a few calmer choices.",
            "The timeline moved, but your plan is still alive.",
            "You can win these days back one decision at a time.",
            "Treat this as a signal to protect the next stretch.",
            "A delayed goal is not a failed goal.",
            "This is the kind of moment Delayd is built to make visible.",
            "Now the cost is clear. Let that clarity help the next choice."
        ],
        .highImpact: [
            "That was a meaningful delay. Take a breath and protect the next choice.",
            "Big spends move dreams. Now you can decide what happens next.",
            "This one had weight, but the story is not finished.",
            "The impact is real. So is your ability to recover.",
            "A large slip needs a calm reset, not guilt.",
            "You saw the time cost. Let that protect the rest of the week.",
            "This is a strong signal to pause before the next spend.",
            "One expensive moment does not erase the goal.",
            "Use this impact as a checkpoint.",
            "Your dream can absorb this if the next choices are cleaner."
        ]
    ]

    private static let coach: [ToneCopyCategory: [String]] = motivational.mapValues {
        $0.map { $0.replacingOccurrences(of: "dream", with: "plan") }
    }

    private static let neutral: [ToneCopyCategory: [String]] = [
        .quietWeek: (1...10).map { "No recent expenses changed your goal timeline. Check \($0)." },
        .recurringSpend: (1...10).map { "A repeated merchant is contributing to goal delay. Pattern \($0)." },
        .weeklyBudget: (1...10).map { "Your weekly delay total changed based on logged expenses. Update \($0)." },
        .goalSlipped: (1...10).map { "The goal timeline moved backward after recent expenses. Slip \($0)." },
        .highImpact: (1...10).map { "This expense created a high delay impact. Impact \($0)." }
    ]

    private static let toughLove: [ToneCopyCategory: [String]] = [
        .quietWeek: (1...10).map { "Quiet week. Good. Do not turn checkpoint \($0) into a delayed week." },
        .recurringSpend: (1...10).map { "Repeat spend \($0) is quietly pushing your goal away." },
        .weeklyBudget: (1...10).map { "Your weekly delay budget is getting used. Pay attention to signal \($0)." },
        .goalSlipped: (1...10).map { "Your goal slipped because spending moved it there. Marker \($0)." },
        .highImpact: (1...10).map { "That spend cost real time. Decision point \($0): was it worth the delay?" }
    ]

    private static let drillSergeant: [ToneCopyCategory: [String]] = [
        .quietWeek: (1...10).map { "Quiet log \($0). Hold the line and keep the dream protected." },
        .recurringSpend: (1...10).map { "Repeat spend \($0) detected. Skip the next one and win days back." },
        .weeklyBudget: (1...10).map { "Weekly delay marker \($0) is climbing. Tighten the next choice." },
        .goalSlipped: (1...10).map { "Goal slipped \($0). Reset now: protect before another spend." },
        .highImpact: (1...10).map { "High-impact spend \($0). Recover with the next protected amount." }
    ]
}
