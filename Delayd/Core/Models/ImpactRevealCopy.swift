import Foundation

/// Severity bucket used by `ImpactRevealCopy` to pick a tone-appropriate
/// message after a spend is logged. Combines the spend's *time cost*
/// (`delayDays`) with its *money weight* relative to the user's monthly
/// savings target — so a ₹5,000 spend reads "major" even when the day count
/// is small, and a ₹50 spend reads "light" even if the user's target makes
/// every rupee feel expensive.
///
/// Buckets are ordered light → moderate → serious → major. Each bucket
/// owns ~12 hand-written lines per `DelaydTone` so the user sees real
/// variety across logs (≥50 lines per tone, no AI in V1).
enum ImpactSeverity: String, CaseIterable {
    case light
    case moderate
    case serious
    case major

    /// Pick a bucket from a logged spend's day-cost and money-weight.
    ///
    /// `weightRatio` is `amount / monthlySavingsTarget` — i.e. "this spend
    /// was X% of one month's savings". We bias toward the harsher of the
    /// two signals so a high-dollar spend that mathematically delays only
    /// a single day still feels like a serious moment, and a tiny spend
    /// that nominally delays many days still reads as light.
    static func classify(delayDays: Int, weightRatio: Double) -> ImpactSeverity {
        let days = max(delayDays, 0)
        let ratio = max(weightRatio, 0)

        let dayBucket: ImpactSeverity
        switch days {
        case 0...1: dayBucket = .light
        case 2...3: dayBucket = .moderate
        case 4...7: dayBucket = .serious
        default: dayBucket = .major
        }

        let weightBucket: ImpactSeverity
        switch ratio {
        case ..<0.05: weightBucket = .light       // < 5% of monthly target
        case 0.05..<0.20: weightBucket = .moderate // 5-20%
        case 0.20..<0.50: weightBucket = .serious  // 20-50%
        default: weightBucket = .major             // 50%+ — half a month
        }

        // Pick the harsher of the two so a single-day delay on a ₹5,000
        // spend still feels weighty, and many-day delays on tiny spends
        // don't get over-dramatized.
        return max(dayBucket, weightBucket)
    }
}

extension ImpactSeverity: Comparable {
    private var order: Int {
        switch self {
        case .light: 0
        case .moderate: 1
        case .serious: 2
        case .major: 3
        }
    }

    static func < (lhs: ImpactSeverity, rhs: ImpactSeverity) -> Bool {
        lhs.order < rhs.order
    }
}

/// Single source of truth for the message shown after a spend is logged.
/// Used by both:
///   • `DelayedImpactRevealView` — the in-app reveal sheet
///   • `QuickCaptureExpenseIntent` — the Shortcuts result snippet
///
/// Same `(amount, days, goalName)` always picks the same line in both
/// surfaces, so logging via Shortcut and then opening the app shows the
/// same wording — never a contradiction.
enum ImpactRevealCopy {
    /// Pick a deterministic line for this spend.
    /// - Parameters:
    ///   - tone: User's chosen voice (from `UserSettings.tone`).
    ///   - days: Calculated delay days from `DelayCalculator`.
    ///   - amount: Spend amount in user's currency.
    ///   - monthlyTarget: User's `monthlySavingsTarget` (used for weight).
    ///   - goalName: Already title-cased name of the affected dream.
    /// - Returns: A complete sentence sized for both UI and Siri voice.
    static func line(
        tone: DelaydTone,
        days: Int,
        amount: Double,
        monthlyTarget: Double,
        goalName: String
    ) -> String {
        let weightRatio = monthlyTarget > 0 ? amount / monthlyTarget : 0
        let severity = ImpactSeverity.classify(delayDays: days, weightRatio: weightRatio)
        let candidates = lines(tone: tone, severity: severity)
        guard !candidates.isEmpty else {
            return ToneCopy.delayReveal(tone: tone, days: max(days, 1), goalName: goalName)
        }

        // Stable seed from the inputs so same spend ⇒ same line in app + Shortcut.
        let seed = abs(Int(amount.rounded()) &+ days &* 31 &+ goalName.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        let template = candidates[seed % candidates.count]
        return render(template, days: days, goalName: goalName)
    }

    /// Total line count surfaced in Settings → Tone preview.
    static func totalLineCount(for tone: DelaydTone) -> Int {
        ImpactSeverity.allCases.reduce(0) { $0 + lines(tone: tone, severity: $1).count }
    }

    // MARK: - Template rendering

    /// Substitutes `{days}`, `{dayWord}`, and `{goal}` placeholders so each
    /// line stays short to author but still reads as a personalized message.
    private static func render(_ template: String, days: Int, goalName: String) -> String {
        let safeDays = max(days, 1)
        let dayWord = safeDays == 1 ? "day" : "days"
        return template
            .replacingOccurrences(of: "{days}", with: String(safeDays))
            .replacingOccurrences(of: "{dayWord}", with: dayWord)
            .replacingOccurrences(of: "{goal}", with: goalName)
    }

    private static func lines(tone: DelaydTone, severity: ImpactSeverity) -> [String] {
        switch tone {
        case .motivational: return motivational[severity] ?? []
        case .coach: return coach[severity] ?? []
        case .neutral: return neutral[severity] ?? []
        case .toughLove: return toughLove[severity] ?? []
        case .drillSergeant: return drillSergeant[severity] ?? []
        }
    }

    // MARK: - Motivational (warm, supportive — celebrates resilience)

    private static let motivational: [ImpactSeverity: [String]] = [
        .light: [
            "Tiny ripple — {goal} only shifted {days} {dayWord}. You'll wave that off in a week. 💜",
            "{days} {dayWord} is barely a blip. {goal} still has all its momentum. 🌱",
            "Soft landing: {goal} moved {days} {dayWord}. One quiet day puts it right back.",
            "Small spend, small delay — {days} {dayWord}. Your dream stays in close view.",
            "You've got plenty of room. {goal} only drifted {days} {dayWord}.",
            "Light touch: {days} {dayWord}. Nothing a clean afternoon can't recover.",
            "{goal} barely felt this — {days} {dayWord} and the timeline holds steady.",
            "Recoverable in a heartbeat. {goal} just nudged {days} {dayWord}. 💪",
            "Small choice today, small impact: {days} {dayWord} on {goal}.",
            "Easy reset. {days} {dayWord} on {goal} — you're still on the rails.",
            "This one barely registers. {goal} keeps its shape and pace.",
            "{goal} held the line. Only {days} {dayWord} of give. Keep going. ✨"
        ],
        .moderate: [
            "Real impact, but recoverable: {goal} moved {days} {dayWord}. You know the play.",
            "{goal} took a {days}-{dayWord} step back — one steady week pulls it forward again. 💪",
            "Mid-weight nudge. {days} {dayWord} on {goal}, and you can win that back.",
            "Pause, breathe: {days} {dayWord} on {goal}. A clean stretch resets the curve.",
            "Worth noticing — {goal} slipped {days} {dayWord}. The next choice matters.",
            "Felt that one. {days} {dayWord} on {goal} is the cost — protect the next spend.",
            "{goal} is still in reach. {days} {dayWord} of slip, plenty of runway left.",
            "This is where small habits decide weeks. {goal} took {days} {dayWord} today.",
            "Recoverable territory. {days} {dayWord} on {goal} — make the next call cleaner. 🌟",
            "{goal} blinked: {days} {dayWord} back. One protected stretch reverses it.",
            "You've got this. {goal} drifted {days} {dayWord} — well within the comeback zone.",
            "The kind of slip that teaches: {days} {dayWord} on {goal}. Channel it."
        ],
        .serious: [
            "Heavy moment: {goal} moved {days} {dayWord}. This one needs intention from here.",
            "{days} {dayWord} on {goal} is real. Use this as the line in the sand. 💜",
            "That hit {goal} hard — {days} {dayWord} of delay. Slow choices win it back.",
            "The dream felt that one. {days} {dayWord} back on {goal} — but still alive.",
            "Significant: {goal} slipped {days} {dayWord}. The story is yours to rewrite.",
            "This one weighs on the timeline. {days} {dayWord} from {goal}. Stay deliberate.",
            "{goal} just took {days} {dayWord}. Big? Yes. Final? Not even close.",
            "A proper setback: {days} {dayWord} on {goal}. Next move counts twice as much.",
            "Tough log to record — {goal} lost {days} {dayWord}. You can rebuild the gap.",
            "Real time gone here. {goal} pushed {days} {dayWord} — slow and steady from here. 🌱",
            "Hard one. {days} {dayWord} on {goal} — protect the rest of the week with care.",
            "{goal} slipped meaningfully: {days} {dayWord}. Recovery starts with the next quiet hour."
        ],
        .major: [
            "Heavy hit: {goal} just moved {days} {dayWord} back. Take a breath, then plan the recovery. 💜",
            "Big one. {goal} pushed {days} {dayWord} — the kind of spend worth sleeping on next time.",
            "Major weight on {goal}: {days} {dayWord} gone. Your dream isn't broken; it just needs care.",
            "That moved the deadline meaningfully. {days} {dayWord} on {goal} calls for a real reset.",
            "Tough log. {goal} lost {days} {dayWord} — and lots of it can come back with a calm month.",
            "{goal} took a hit: {days} {dayWord}. Big spends teach the loudest lessons.",
            "This is a chapter, not the ending. {days} {dayWord} on {goal} — write the next one stronger.",
            "Real cost: {days} {dayWord} from {goal}. Protect your peace, then protect the next spend. ✨",
            "Major slip — {goal} moved {days} {dayWord}. One recovery week tightens it back up.",
            "{goal} took weight: {days} {dayWord}. Use the sting; it's the cheapest tutor you'll get.",
            "Big number on the page: {days} {dayWord} on {goal}. Walk it back gently from here.",
            "{goal} stretched {days} {dayWord} further. Now the comeback gets to be the story. 💪"
        ]
    ]

    // MARK: - Coach (encouraging push, plan/play language)

    private static let coach: [ImpactSeverity: [String]] = [
        .light: [
            "Light contact: {goal} moved {days} {dayWord}. Run the next play clean. 🎯",
            "{days} {dayWord} on {goal} — minor. Reset and keep the tempo.",
            "Small dip in the timeline: {days} {dayWord}. Stay with the plan.",
            "{goal} barely flinched — {days} {dayWord}. Keep stacking clean choices.",
            "On the ledger: {days} {dayWord} on {goal}. Easy correction tomorrow.",
            "Minor delay logged. {days} {dayWord} on {goal} — back to plan.",
            "Quick adjustment. {goal} took {days} {dayWord}; refocus on the next rep.",
            "Tiny tap. {goal} stays on schedule despite the {days}-{dayWord} bump.",
            "Read it, log it, move on. {days} {dayWord} on {goal}. 🎯",
            "That's a minor variance, not a setback. {days} {dayWord} on {goal}.",
            "Small cost, easy fix. Tighten the next decision and {goal} reabsorbs it.",
            "Drill it tomorrow: {days} {dayWord} on {goal}. Keep the cadence."
        ],
        .moderate: [
            "Felt that — {days} {dayWord} on {goal}. Reset, refocus, run cleaner. 🎯",
            "{goal}: {days} {dayWord} back on the clock. You know the play.",
            "Mid-weight slip. {days} {dayWord} on {goal} — reset the next decision deliberately.",
            "Pause point. {goal} lost {days} {dayWord}. Make the next call your sharpest.",
            "{days} {dayWord} on {goal}. Coach mode: protect the rest of the week.",
            "{goal} drifted {days} {dayWord}. Step into the next choice with focus.",
            "Real ground given: {days} {dayWord}. Next rep pulls it back, one clean choice at a time.",
            "Mid-game adjustment: {days} {dayWord} on {goal}. Run the playbook.",
            "Time to tighten up. {goal} took {days} {dayWord} — protect the next non-essential.",
            "{goal} took a {days}-{dayWord} hit. Reset the breath, reset the plan.",
            "Coachable moment: {days} {dayWord} on {goal}. Where can you cut next?",
            "Notice this slip. {days} {dayWord} on {goal} — one clean stretch reverses it."
        ],
        .serious: [
            "Real setback: {goal} lost {days} {dayWord}. Tighten up — next choice matters more than ever. 🎯",
            "Heavy on the plan. {days} {dayWord} on {goal}. Time for a deliberate reset.",
            "{goal} slipped {days} {dayWord}. Don't compound it — protect the next spend hard.",
            "Tough rep. {days} {dayWord} on {goal}. The next decision is the comeback move.",
            "Significant cost: {days} {dayWord}. Pause the next non-essential and reclaim ground.",
            "The play broke down. {goal} lost {days} {dayWord}. Reset, refocus, run it back.",
            "That's a meaningful slip — {days} {dayWord} on {goal}. Lock in the next decision.",
            "Game-time honesty: {goal} dropped {days} {dayWord}. The next call is yours to nail.",
            "Real delay registered: {days} {dayWord}. Coach voice: hard pause before the next spend.",
            "Tight grip from here. {goal} took {days} {dayWord} — you don't get a second one this week.",
            "{goal} bled {days} {dayWord}. Discipline over impulse on the next rep.",
            "Big cost on the scoreboard. {days} {dayWord} on {goal}. Run the recovery play."
        ],
        .major: [
            "Major rep gone wrong: {goal} pushed {days} {dayWord}. Time for a hard reset. 🎯",
            "{goal} took {days} {dayWord} — that's the kind of slip that calls for a recovery week.",
            "Real hit on the plan: {days} {dayWord} on {goal}. Lock the next non-essential down.",
            "Honest scoreboard: {goal} lost {days} {dayWord}. Coach mode goes strict from here.",
            "Massive ground given. {days} {dayWord} on {goal} — protect every spend this week.",
            "{goal} took a heavy hit: {days} {dayWord}. The next call is the most important one.",
            "Real delay: {days} {dayWord} on {goal}. Run the recovery play, no exceptions.",
            "Big spend, big setback. {days} {dayWord} on {goal}. Tighten the next 7 days.",
            "{goal} dropped {days} {dayWord}. This one demands a deliberate week, not just a deliberate hour.",
            "The plan took a bruise. {days} {dayWord} on {goal} — reset the protocol, run it cleaner.",
            "Major ground lost: {days} {dayWord}. Coach call: pause non-essentials until {goal} catches back up.",
            "{goal} slipped {days} {dayWord}. Time to play tighter, not louder. 🎯"
        ]
    ]

    // MARK: - Neutral (factual, calm, no emotion)

    private static let neutral: [ImpactSeverity: [String]] = [
        .light: [
            "{goal}: +{days} {dayWord} based on this expense and your monthly target.",
            "Logged. {goal} timeline shifted by {days} {dayWord}.",
            "This expense pushed {goal} {days} {dayWord} further out.",
            "Delay added: {days} {dayWord} on {goal}.",
            "Recorded. {goal} now {days} {dayWord} behind its prior estimate.",
            "{days}-{dayWord} delay applied to {goal} based on current pace.",
            "{goal} estimated date moved {days} {dayWord} later.",
            "Result: +{days} {dayWord} on {goal}.",
            "{goal} timeline updated: {days} {dayWord} of additional delay.",
            "Expense impact: {days} {dayWord} on {goal}.",
            "New estimate: {goal} is {days} {dayWord} further away.",
            "Updated. {goal} delay total increased by {days} {dayWord}."
        ],
        .moderate: [
            "Moderate impact: {goal} moved {days} {dayWord} based on this expense.",
            "{goal}: +{days} {dayWord}. Above the lightweight threshold.",
            "This spend added {days} {dayWord} of delay to {goal}.",
            "Logged. {goal} is now {days} {dayWord} behind its previous estimate.",
            "Result: +{days} {dayWord} on {goal} — moderate band.",
            "{goal} timeline shifted {days} {dayWord} later. Within the moderate range.",
            "Recorded. {goal} delay grew by {days} {dayWord}.",
            "{days}-{dayWord} setback on {goal} computed from this expense.",
            "{goal} estimated date now {days} {dayWord} further out.",
            "Expense impact: {days} {dayWord} on {goal}. Moderate severity.",
            "Delay update: {goal} +{days} {dayWord}.",
            "{goal}: timeline +{days} {dayWord} from this log."
        ],
        .serious: [
            "High impact: {goal} moved {days} {dayWord}.",
            "Serious delay: +{days} {dayWord} on {goal}.",
            "{goal}: +{days} {dayWord}. Above the moderate threshold.",
            "{goal} timeline pushed {days} {dayWord} later. Serious band.",
            "Recorded. {goal} now {days} {dayWord} behind — serious slip.",
            "Result: {days} {dayWord} added to {goal}.",
            "Delay update: +{days} {dayWord} on {goal}, classified serious.",
            "{goal} estimated date now {days} {dayWord} further out.",
            "Expense impact: {days} {dayWord} on {goal}.",
            "{goal} timeline +{days} {dayWord}. Serious classification.",
            "Logged: {goal} dropped {days} {dayWord} of progress.",
            "{goal}: +{days} {dayWord}, above the moderate band."
        ],
        .major: [
            "Major impact: {goal} moved {days} {dayWord} back.",
            "{goal}: +{days} {dayWord}. Major severity.",
            "Major delay: this expense added {days} {dayWord} to {goal}.",
            "Recorded. {goal} timeline pushed {days} {dayWord} later. Major slip.",
            "{goal} now {days} {dayWord} behind its prior estimate. Major band.",
            "Result: +{days} {dayWord} on {goal}. Major severity classification.",
            "Major variance: {goal} timeline shifted by {days} {dayWord}.",
            "Logged. {goal} dropped {days} {dayWord} of progress — major.",
            "Delay update: +{days} {dayWord} on {goal}. Severity: major.",
            "Expense impact (major): {days} {dayWord} on {goal}.",
            "{goal} estimated date now {days} {dayWord} later. Major delay.",
            "Major: {goal} pushed {days} {dayWord}."
        ]
    ]

    // MARK: - Tough Love (blunt, no comfort)

    private static let toughLove: [ImpactSeverity: [String]] = [
        .light: [
            "Only {days} {dayWord}, but small leaks sink dreams. Notice it.",
            "{days} {dayWord} on {goal}. Don't pretend it's nothing.",
            "Tiny? Sure. But every {days} {dayWord} on {goal} is real time gone.",
            "Light slip — and they add up. {goal} just lost {days} {dayWord}.",
            "Small spend, real cost: {days} {dayWord} on {goal}. Don't shrug it off.",
            "{goal} drifted {days} {dayWord}. Easy to ignore, easier to repeat.",
            "{days} {dayWord} doesn't sound like much. Multiply by a month.",
            "Logged: {days} {dayWord} on {goal}. Patterns start here.",
            "{goal} took {days} {dayWord}. The 'just one' line costs the most over time.",
            "Minor delay, major habit if it repeats. {days} {dayWord} on {goal}.",
            "Stacking quiet slips? {goal} took {days} {dayWord} this time.",
            "{days} {dayWord} on {goal}. Each one is a vote against the dream."
        ],
        .moderate: [
            "{days} {dayWord} further from {goal}. Was it worth it?",
            "Real cost: {days} {dayWord} on {goal}. Own it before it grows.",
            "{goal} just lost {days} {dayWord}. That's not invisible spending.",
            "{days} {dayWord} gone. Keep this up and {goal} becomes a suggestion.",
            "Honest column: {days} {dayWord} from {goal}. Comfortable spending has a price.",
            "{goal} drifted {days} {dayWord}. The deadline is moving — are you?",
            "That's {days} {dayWord} you'll have to win back. The clock noticed.",
            "{goal} dropped {days} {dayWord}. Either change the behavior or change the dream.",
            "{days} {dayWord} bought you a moment. {goal} paid the bill.",
            "Plain truth: {days} {dayWord} on {goal}. Small comforts, real delay.",
            "{goal} just slipped {days} {dayWord}. The pattern is the warning.",
            "{days} {dayWord} from {goal}. The next call has weight."
        ],
        .serious: [
            "{goal} just lost {days} {dayWord}. This is where casual spending starts costing real time.",
            "Serious slip — {days} {dayWord} from {goal}. Stop calling spends 'small'.",
            "{days} {dayWord} from {goal}. The dream is louder now; listen.",
            "{goal} dropped {days} {dayWord}. Pretend you didn't see it and the number doubles.",
            "That spend cost {days} {dayWord}. Either it was worth it or it wasn't.",
            "{days} {dayWord} on {goal}. Comfortable choices, uncomfortable timeline.",
            "Honest mirror: {goal} just slipped {days} {dayWord}. What changes now?",
            "{goal} took {days} {dayWord}. Casual spends, casual delay — your dream is the casualty.",
            "Real ground given: {days} {dayWord}. The 'I deserve this' tax is showing up here.",
            "{goal} lost {days} {dayWord}. Track it now or live with it later.",
            "Serious column entry: {days} {dayWord} from {goal}. The comeback won't be free.",
            "{days} {dayWord} on {goal}. The pattern speaks louder than the rationale."
        ],
        .major: [
            "{days} {dayWord} gone from {goal}. If it matters, this kind of spend needs a hard pause next time.",
            "Major slip: {days} {dayWord} on {goal}. Hope is not a strategy — protect the next one.",
            "{goal} just lost {days} {dayWord}. The dream isn't dead, but it's bleeding.",
            "{days} {dayWord} on {goal}. Big spends like this keep happening, the dream keeps slipping.",
            "Heavy: {goal} dropped {days} {dayWord}. Either change behavior or rewrite the deadline.",
            "{days} {dayWord} from {goal}. The math is brutal because the spend was.",
            "Real damage: {days} {dayWord} on {goal}. Comfortable now, expensive later.",
            "{goal} took {days} {dayWord}. The dream is shouting — answer it.",
            "{days} {dayWord} gone. {goal} doesn't care about the reason — only the result.",
            "Major hit: {goal} slipped {days} {dayWord}. Next spend needs a real conversation with yourself.",
            "Honest entry: {days} {dayWord} on {goal}. Big spends create big delays, every time.",
            "{goal} just lost {days} {dayWord}. The deadline isn't theoretical anymore."
        ]
    ]

    // MARK: - Drill Sergeant (firm, action-focused, no negotiation)

    private static let drillSergeant: [ImpactSeverity: [String]] = [
        .light: [
            "Strict reset: {goal} moved {days} {dayWord}. Protect the next spend. No drift.",
            "{days} {dayWord} on {goal}. Tighten up before it stacks.",
            "Small slip, strict response. {goal} took {days} {dayWord} — lock the next decision.",
            "{goal} lost {days} {dayWord}. Reset now, no excuses.",
            "Discipline check: {days} {dayWord} on {goal}. Hold the line.",
            "Marker: {days} {dayWord} on {goal}. Next non-essential gets paused.",
            "{goal} drifted {days} {dayWord}. Strict mode: catch it now.",
            "{days} {dayWord} of slip. Reset the protocol immediately.",
            "Logged. {goal} took {days} {dayWord} — eyes on the next spend.",
            "{goal} lost {days} {dayWord}. Tighten the next 24 hours.",
            "Order: protect the next spend after this {days}-{dayWord} drift on {goal}.",
            "Strict count: {days} {dayWord} on {goal}. No second slip this week."
        ],
        .moderate: [
            "{goal} lost {days} {dayWord}. Pause the next non-essential. No drift. 🏁",
            "Strict reset: {days} {dayWord} on {goal}. Protect the next decision hard.",
            "{days} {dayWord} on {goal}. Lock the rest of the week down.",
            "Discipline mode on: {goal} took {days} {dayWord}. Tighten everything.",
            "{goal} drifted {days} {dayWord}. Order: pause the next non-essential spend.",
            "Marker: {days} {dayWord} of slip. Don't compound it.",
            "{goal} dropped {days} {dayWord}. Strict count starts now — protect every choice.",
            "{days} {dayWord} on {goal}. The next spend gets sleeves-rolled scrutiny.",
            "Logged. {goal} lost {days} {dayWord}. Tighten the protocol immediately.",
            "{goal} slipped {days} {dayWord}. Recover with a protected amount before the next spend.",
            "Strict reset: {days} {dayWord} on {goal}. No softness on the next call.",
            "{goal}: {days} {dayWord} of drift. Lock down. No excuses."
        ],
        .serious: [
            "{goal} lost {days} {dayWord}. Tighten the week. No more drift, no exceptions. 🏁",
            "Serious slip: {days} {dayWord} on {goal}. Strict protocol starts now.",
            "{days} {dayWord} off {goal}. Pause non-essentials until ground is recovered.",
            "{goal} dropped {days} {dayWord}. Hard reset on every spend this week.",
            "Order: lock down the rest of the week. {days} {dayWord} on {goal} won't repeat.",
            "{goal} bled {days} {dayWord}. Strict reset, no negotiation.",
            "Discipline check failed: {days} {dayWord} on {goal}. Recovery mode engaged.",
            "{goal} slipped {days} {dayWord}. The next spend is the comeback or the cliff.",
            "Mark it: {days} {dayWord} on {goal}. Strict count, strict response.",
            "{goal} took {days} {dayWord}. Tighten the schedule. Tighten the spending.",
            "Serious cost: {days} {dayWord}. {goal} demands a clean week — make it happen.",
            "{days} {dayWord} of delay. Protect the next 7 days like the dream depends on it."
        ],
        .major: [
            "Major delay: {days} {dayWord} pushed away. Recover with a protected amount next. 🏁",
            "{goal} lost {days} {dayWord}. Strict recovery week starts immediately.",
            "{days} {dayWord} on {goal}. Lock down every non-essential spend until further notice.",
            "Major slip — protocol failure. {goal} took {days} {dayWord}. Reset hard.",
            "{goal} dropped {days} {dayWord}. No more drift. Every spend gets scrutinized now.",
            "Heavy hit: {days} {dayWord} on {goal}. Discipline week mandatory.",
            "Major cost: {days} {dayWord} on {goal}. Recovery isn't optional.",
            "{goal} slipped {days} {dayWord}. Hard pause on the next non-essential. No exceptions.",
            "{days} {dayWord} gone. Strict count: protect a matching amount before the next spend.",
            "{goal} bled {days} {dayWord} of progress. Tighten the entire month.",
            "Major delay logged. {goal} took {days} {dayWord}. Discipline mode stays on until recovered.",
            "{goal} just lost {days} {dayWord}. Lock the budget. Lock the schedule. No drift."
        ]
    ]
}
