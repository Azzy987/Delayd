import Foundation

/// Emotional tone of in-app copy — set during onboarding, stored in UserSettings,
/// consumed by SmartInsightCard, DelayedImpactRevealView, and notifications.
///
/// The order of cases is the order shown in the tone picker (gentlest →
/// strongest), and ranges from supportive copy through to a strict coach voice
/// that gives direct accountability on avoidable spends.
enum DelaydTone: String, CaseIterable, Identifiable, Codable {
    case motivational
    case coach
    case neutral
    case toughLove
    case drillSergeant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .motivational: "Motivational"
        case .coach: "Coach"
        case .neutral: "Neutral"
        case .toughLove: "Tough Love"
        case .drillSergeant: "Strict Coach"
        }
    }

    var subtitle: String {
        switch self {
        case .motivational: "Warm nudges that celebrate progress."
        case .coach: "Encouraging push - like a trainer in your corner."
        case .neutral: "Straight facts, no emotion."
        case .toughLove: "Blunt accountability without comfort."
        case .drillSergeant: "Firm, intense, and action-focused."
        }
    }

    var usageGuide: String {
        switch self {
        case .motivational:
            "Best for users who respond to encouragement and want Delayd to feel supportive."
        case .coach:
            "Best for users who want direct habit coaching without harsh language."
        case .neutral:
            "Best for users who only want factual delay math and minimal emotion."
        case .toughLove:
            "Best for users who want blunt accountability without harsh pressure."
        case .drillSergeant:
            "Best for users who want firm discipline and specific next-action pressure."
        }
    }

    var emoji: String {
        switch self {
        case .motivational: "🌱"
        case .coach: "🎯"
        case .neutral: "📊"
        case .toughLove: "⚠️"
        case .drillSergeant: "🏁"
        }
    }

    /// Hint shown beneath the strongest tones so the user knows what they're
    /// signing up for. Returns `nil` for tones that don't need a warning.
    var intensityWarning: String? {
        switch self {
        case .drillSergeant:
            return "Heads up: this voice is firm and direct after every expense."
        case .toughLove, .motivational, .neutral, .coach:
            return nil
        }
    }

    /// Sample line shown on the tone picker so the user feels the difference
    /// before committing.
    var sampleLine: String {
        switch self {
        case .motivational:
            "You've got this — ₹500 today is a small step, your dream is still on track. 💜"
        case .coach:
            "₹500 logged. That's a 2-day setback — shake it off and run the next play clean."
        case .neutral:
            "You logged ₹500. This delays Bali by 2 days based on your current pace."
        case .toughLove:
            "₹500 gone. That's 2 more days between you and Bali. Was it worth it?"
        case .drillSergeant:
            "₹500 logged. Bali moved 2 days back. Strict reset: protect the next ₹500 before another spend."
        }
    }
}

/// Centralized copy provider so tone strings live in one place and any surface
/// (insights, reveal, notifications) reads from here.
enum ToneCopy {
    // MARK: - Delay reveal (after logging an expense)

    static func delayReveal(tone: DelaydTone, days: Int, goalName: String) -> String {
        let dayWord = days == 1 ? "day" : "days"
        switch tone {
        case .motivational:
            return "\(goalName) shifted \(days) \(dayWord). Still within reach — one clean week puts it back. 💪"
        case .coach:
            return "\(goalName): \(days) \(dayWord) back on the clock. You know the play — reset and run it cleaner tomorrow. 🎯"
        case .neutral:
            return "\(goalName): +\(days) \(dayWord) based on this spend and your monthly target."
        case .toughLove:
            return "\(days) \(dayWord) further from \(goalName). Keep this up and the goal becomes a suggestion."
        case .drillSergeant:
            return "\(goalName) lost \(days) \(dayWord). No drift: pause the next non-essential spend and protect money back."
        }
    }

    // MARK: - Smart insight (rotating banner on Home)

    /// Context-aware data the rotating Smart Insight banner needs to phrase
    /// the day's nudge. Keep this struct dumb (just numbers + names) so the
    /// caller (HomeViewModel) does the math and ToneCopy stays a pure string
    /// formatter.
    struct InsightContext {
        /// The user's most-frequent merchant/tag this week, e.g. "coffee runs".
        /// Used by the "Skipping this 4x/month would put your goal 8 days
        /// closer" variant. `nil` when there isn't enough signal yet.
        var topRecurringMerchant: String?
        /// Estimated days closer to goal if the user skipped that merchant
        /// 4x in a month. Drives the same variant.
        var topRecurringSkipDelta: Int

        /// What % of the user's weekly delay budget today's expenses ate up.
        /// `nil` when there are no expenses logged this week.
        var weeklyDelayPercent: Int?

        /// Active goal's name and how many days it has slipped from its
        /// original timeline. Used by the "Your [Goal] just slipped …"
        /// variant. `nil` when there's no slip to surface.
        var slippedGoalName: String?
        var slippedGoalDays: Int
        /// Whether the active goal is net-ahead after protection offsets.
        var isAhead: Bool
        var aheadDays: Int

        /// True if there is meaningful spending this week. When false we
        /// fall back to a single supportive line per tone.
        var hasActivity: Bool
    }

    /// Default fallback used by callers that don't have context yet (e.g.,
    /// fresh installs). Preserves the original simple per-tone copy.
    static func smartInsight(tone: DelaydTone) -> String {
        smartInsight(tone: tone, context: InsightContext(
            topRecurringMerchant: nil,
            topRecurringSkipDelta: 0,
            weeklyDelayPercent: nil,
            slippedGoalName: nil,
            slippedGoalDays: 0,
            isAhead: false,
            aheadDays: 0,
            hasActivity: false
        ))
    }

    /// Rotating Smart Insight (per V1 blueprint §7). Picks one of three
    /// formats deterministically per day so the banner doesn't flicker on
    /// every render but still feels alive day-to-day:
    ///   1. "Skipping this 4x/month would put your goal X days closer"
    ///   2. "This is N% of your weekly delay budget"
    ///   3. "Your [Goal] just slipped to a new estimated date"
    /// Variants the context can't support are skipped, then the day-of-year
    /// modulo picks among what's left. Falls back to a tone line.
    static func smartInsight(tone: DelaydTone, context: InsightContext) -> String {
        if context.isAhead, context.aheadDays > 0 {
            return aheadVariant(tone: tone, days: context.aheadDays)
        }

        // Build the candidate pool from whatever the context can support.
        var candidates: [String] = []

        if let merchant = context.topRecurringMerchant, context.topRecurringSkipDelta > 0 {
            candidates.append(skipVariant(
                tone: tone,
                merchant: merchant,
                days: context.topRecurringSkipDelta
            ))
        }

        if let percent = context.weeklyDelayPercent, percent > 0 {
            candidates.append(percentVariant(tone: tone, percent: percent))
        }

        if let goal = context.slippedGoalName, context.slippedGoalDays > 0 {
            candidates.append(slipVariant(
                tone: tone,
                goalName: goal,
                days: context.slippedGoalDays
            ))
        }

        guard !candidates.isEmpty else {
            #if DEBUG
            print("[ToneCopy] smartInsight: no context candidates — using fallback (hasActivity: \(context.hasActivity))")
            #endif
            return fallbackInsight(tone: tone, hasActivity: context.hasActivity)
        }

        // Stable per-day rotation so the banner doesn't change on every redraw
        // but still varies day-to-day.
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return candidates[day % candidates.count]
    }

    private static func skipVariant(tone: DelaydTone, merchant: String, days: Int) -> String {
        let dayWord = days == 1 ? "day" : "days"
        switch tone {
        case .motivational:
            return "Skipping \(merchant) 4x/month would put your goal \(days) \(dayWord) closer. Small wins compound. 💪"
        case .coach:
            return "Drop \(merchant) 4x/month and you bank \(days) \(dayWord) toward your goal. That's the play. 🎯"
        case .neutral:
            return "Skipping \(merchant) 4x/month would shorten your goal by \(days) \(dayWord)."
        case .toughLove:
            return "\(merchant.capitalized) 4x/month is costing you \(days) \(dayWord) on your goal. Cut it or own it."
        case .drillSergeant:
            return "\(merchant.capitalized) 4x/month costs \(days) \(dayWord). Strict move: skip the next one."
        }
    }

    private static func percentVariant(tone: DelaydTone, percent: Int) -> String {
        switch tone {
        case .motivational:
            return "This week's spend is \(percent)% of your delay budget — plenty of room to keep momentum."
        case .coach:
            return "You're \(percent)% into your weekly delay budget. Pace yourself — you've got this. 🎯"
        case .neutral:
            return "This is \(percent)% of your weekly delay budget."
        case .toughLove:
            return "\(percent)% of your weekly delay budget — gone. Six days, one budget."
        case .drillSergeant:
            return "\(percent)% of your weekly delay budget is used. Lock down the next spend."
        }
    }

    private static func slipVariant(tone: DelaydTone, goalName: String, days: Int) -> String {
        let dayWord = days == 1 ? "day" : "days"
        switch tone {
        case .motivational:
            return "\(goalName) slipped \(days) \(dayWord) — still in reach. One clean week brings it back."
        case .coach:
            return "\(goalName) is \(days) \(dayWord) behind schedule. Reset, refocus, run it back stronger. 🎯"
        case .neutral:
            return "\(goalName) just slipped to a new estimated date (+\(days) \(dayWord))."
        case .toughLove:
            return "\(goalName) slipped \(days) \(dayWord). The deadline is moving — are you?"
        case .drillSergeant:
            return "\(goalName) slipped \(days) \(dayWord). Tighten the next choice and stop the drift."
        }
    }

    private static func aheadVariant(tone: DelaydTone, days: Int) -> String {
        let dayWord = days == 1 ? "day" : "days"
        switch tone {
        case .motivational:
            return "You're ahead by \(days) \(dayWord). Keep this rhythm and your dream arrives sooner. 💜"
        case .coach:
            return "Ahead by \(days) \(dayWord). Protect this momentum and keep running clean. 🎯"
        case .neutral:
            return "Net projection: ahead by \(days) \(dayWord) after protected contributions."
        case .toughLove:
            return "Ahead by \(days) \(dayWord). Good. Don't hand it back on impulse."
        case .drillSergeant:
            return "Ahead \(days) \(dayWord). Hold formation and protect the lead."
        }
    }

    private static func fallbackInsight(tone: DelaydTone, hasActivity: Bool) -> String {
        // No context — supportive line so the banner never reads as broken.
        switch tone {
        case .motivational:
            return ToneCopyLibrary.line(for: tone, category: hasActivity ? .weeklyBudget : .quietWeek, seed: Calendar.current.component(.day, from: .now))
        case .coach:
            return ToneCopyLibrary.line(for: tone, category: hasActivity ? .weeklyBudget : .quietWeek, seed: Calendar.current.component(.day, from: .now))
        case .neutral:
            return ToneCopyLibrary.line(for: tone, category: hasActivity ? .weeklyBudget : .quietWeek, seed: Calendar.current.component(.day, from: .now))
        case .toughLove:
            return ToneCopyLibrary.line(for: tone, category: hasActivity ? .weeklyBudget : .quietWeek, seed: Calendar.current.component(.day, from: .now))
        case .drillSergeant:
            return ToneCopyLibrary.line(for: tone, category: hasActivity ? .weeklyBudget : .quietWeek, seed: Calendar.current.component(.day, from: .now))
        }
    }

    // MARK: - Daily nudge (notifications)

    static func dailyNudge(tone: DelaydTone) -> String {
        switch tone {
        case .motivational:
            "Log today's spend — keeping the picture honest keeps the dream real."
        case .coach:
            "Quick check-in: log today's spend. Discipline beats motivation. 🎯"
        case .neutral:
            "Daily reminder: log expenses to keep delay estimates accurate."
        case .toughLove:
            "Didn't log anything yet? Delays you can't see still count."
        case .drillSergeant:
            "Strict check-in: log today's spend before the day gets blurry."
        }
    }

    // MARK: - Goal slipped (milestone)

    static func goalSlipped(tone: DelaydTone, days: Int, goalName: String) -> String {
        switch tone {
        case .motivational:
            "\(goalName) slipped \(days) days this month — still totally recoverable. One steady week = back on track."
        case .coach:
            "\(goalName) lost \(days) days this month. Time to tighten up the routine — you know what to do. 🎯"
        case .neutral:
            "\(goalName) is \(days) days behind the original timeline."
        case .toughLove:
            "\(goalName) slipped \(days) days. At this rate, rewrite the deadline or change the behavior."
        case .drillSergeant:
            "\(goalName) is \(days) days back this month. Strict reset: protect the next spend."
        }
    }
}
