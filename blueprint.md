# Delayd — Product Blueprint v1

> Source of truth for product concept, flows, and feature scope.
> For visual design tokens and code rules, see AGENTS.md and brand-tokens.md.

---

## 1. Core Concept

Delayd is a behavior-changing financial app that converts spending into time delay toward personal dreams.

**The insight:** Every expense delays a goal by X days. Users don't see "₹500 spent" — they see "₹500 delayed your Bali trip by 2 days."

**One-line pitch:** Delayd shows how every expense delays your dreams — so you spend smarter without budgeting.

---

## 2. Positioning

| Traditional Apps | Delayd |
|------------------|--------|
| Expense tracker | Dream protector |
| Numbers | Emotions |
| Budget control | Life outcome control |
| Past-focused | Future-focused |
| Categories | Goals |

**Anti-references:** Mint, SyncSpend, generic budget apps, anything with pie charts as primary content.
**Aesthetic references:** Paylix, Things 3, Cash App, Cluely.

---

## 3. Target User

Anyone with a savings goal who feels their spending sabotages it. Gender-neutral, age 22-45, smartphone-native, emotionally driven by aspirations rather than spreadsheets.

---

## 4. V1 Feature Scope (LOCKED)

### IN V1
- Goal creation with emoji picker (11 presets: ✈️ 🏖️ 📱 🎮 🏠 🚗 🎓 💍 ⚡ 💰 ⭐)
- Manual expense logging with delay impact reveal
- Goal progress tracking with backward animation
- Smart insights (rotating, mock-generated)
- Settings: monthly savings target, currency, haptics, notifications
- Light + dark mode
- Local-first storage (SwiftData)
- Guest-first (no auth)
- Local Pro entitlement shell for V1 monetization
- Pro: unlimited active dreams
- Pro: rule-based delay coach shown during Quick Log
- Pro: smart local delay reminders
- Pro: weekly dream-protection recap
- Pro: hard-mode confirmation prompts for high-delay spends

### NOT IN V1 (deferred)
- ❌ Income tracking → V1.1 (single "monthly savings target" replaces this)
- ❌ Voice input → V1.1
- ❌ Receipt scanning → V1.2 (Pro feature)
- ❌ Language selection → V2 (English only in V1)
- ❌ Account creation / sign-in
- ❌ Cloud sync (Supabase) → Prompt 10, optional
- ❌ Shared couple goals across different phones (requires account + cloud sync)
- ❌ Cross-device partner activity notifications (when partner logs spend/protects dream)
- ❌ Widgets → V1.1
- ❌ Live Activities → V1.1
- ❌ Multiple currencies per goal
- ❌ Categories breakdown / pie charts
- ❌ Reports tab

### V1 Pro Boundary

V1 Pro must stay local-first and guest-first. The paywall can unlock local
features, but it must not promise account sync, widgets, receipt scanning, or
cloud features as currently available.

V1 Pro includes:
- Unlimited active dreams (free users can keep one active dream)
- Rule-based delay coach before logging a spend
- Smart local notifications/reminders
- Weekly dream-protection recap from local SwiftData
- Hard-mode confirmation before high-delay spends

V1.1 Pro candidates:
- Optional Apple/Google sign-in
- Private cloud sync across iPhone/iPad
- Shared couple goals (invite/link partner, shared progress, shared timeline)
- Partner notifications for shared goals (log/protect events from either partner)
- Widgets
- Receipt scanning

Founder pricing reference (internal):
- Monthly: `$2.99`
- Yearly: `$14.99`
- Lifetime: `$24.99`

---

## 5. Information Architecture

### 4-Tab Structure (LOCKED)

| Tab | SF Symbol | Purpose |
|-----|-----------|---------|
| Home | house.fill | Active goal hero, recent impacts, smart insight |
| Plan | target | All goals with progress |
| History | clock.fill | Expense history with delay impacts (no charts) |
| Settings | gearshape.fill | Currency, monthly target, haptics, debug |

**Floating "+" button** sits above the tab bar (centered, raised), opens Quick Log sheet from any tab.

---

## 6. Core Screens

### 6.1 Onboarding (8 screens)
1. **Welcome** — Lottie hero (300pt), "Dreams move in days", CTA
2. **Insight** — Lottie hero (280pt), sample DelayedImpactCard ("₹500 → delayed Bali by 2 days") + cultural anchor line: *"Most people delay their dream by 2 years without realizing it."* (generic observation, not a claim about Delayd users — until we have real cohort data we don't fabricate aggregate stats)
3. **Choose Dream** — `GoalCategoryIllustrationPicker(style: .bare)` — illustrations clipped to circle (110pt), no white asset background, soft purple selection halo + ring, tight 3-column grid
4. **Goal Details** — Big circle-clipped category illustration (144pt), name + target amount + optional date
5. **Savings Target** — Big amount display + full-width preset rows (one chip per row, icon + amount + months-to-goal + chevron) + Custom dashed-border row that reveals a numeric entry card
6. **Tone** — Emotional tone (motivational / strict / playful) — drives copy in insights, reveals, notifications
7. **Permissions** — Larger preference cards: 56pt icon tile, gradient fill when toggled on, purple-tinted border + soft shadow, scale bump on activation
8. **Ready** — Illustration (220pt), "Your dream is now protected" + CTA

**Layout & motion (Kavsoft-style):**
- Gradient-top screens (Welcome / Insight / Permissions / Ready) use `OnboardingPageLayout` — white card is a **full-width bottom sheet** (top corners rounded, bottom edge flush with screen, soft shadow on top edge). Card height is content-driven and animates with a bouncier spring (`response: 0.42, dampingFraction: 0.72`). The card includes the safe-area inset internally so the Continue button never overlaps the home indicator.
- Per-screen entry: `staggeredAppear` modifier slides+fades+blur-clears title → body → indicator → CTA on a stagger (~80ms steps), replays whenever a screen becomes the active step (driven by env `onboardingDragProgress.activeIndex` + per-screen `Self.stepIndex` constants).
- Paging uses a custom `KavsoftCarousel` (replaces `TabView(.page)`) — drag-driven, rubber-banded at edges; programmatic Continue taps slide horizontally with spring (`response: 0.55, dampingFraction: 0.78`). Off-center pages scale (1 → 0.92), fade (1 → 0.55), and blur (0 → 6pt) live during drag.
- Subtle parallax: gradient-area lottie/illustration shifts up to ±28pt opposite to drag, decorative dots shift at 0.4× for layered depth.

**Paywall placement:**
- Show after Ready screen (step 8 → before main app), framed as "Protect your dream" not "Subscribe".
- Soft paywall: free users get one active dream + manual logging; paywall gates local V1 Pro features only: unlimited active dreams, rule-based delay coach, smart local reminders, weekly recap, and hard-mode prompts.
- Don't gate the first reveal — users must feel the core value (DelayedImpactCard) before they're asked to pay.

### 6.2 Home
- TopBar: greeting + notification bell
- GoalHeroCard (purple gradient, dominant)
- SecondaryCardsRow: "Saved this month" + "Delayed this month"
- SmartInsightCard (premium black banner with subtle purple glow)
- RecentImpactSection (3-5 ExpenseRows with delay framing)
- **WeeklyPulseSection — personal pulse, not aggregate.** Minimal sparkline of the user's own week, no chart axes, with a one-line headline beneath:
  - Positive week: *"You've protected your dream by ₹12,400 this month."*
  - Improving week: *"You've saved 18 days vs. last month."*
  - Slow week: *"3 days slower than last week — small choices add up."*
  - Lines pull from the user's own expense + goal data; we never show "Delayd users achieve X faster" in V1 because we don't have honest aggregate data. Personal pulse is the only social-proof-shaped element that earns its place.

### 6.3 Plan
- "My Plan" header + create goal button
- Featured goal card (largest)
- All goals list (vertical scroll)
- Tap → GoalDetailView (stats + linked expenses)
- Create flow → CreateGoalSheet (emoji picker + details)

### 6.4 History
- Filter bar: goal dropdown + date range
- Grouped list by day
- Each day shows day total: "Spent: ₹X • Delayed: N days"
- ExpenseRow components — never framed as "transactions"

### 6.5 Settings
- Top: Premium banner (Delayd Pro placeholder for V1.1)
- Preferences: currency, monthly savings target, default goal
- Notifications & Feedback: toggles
- Data: export, sync (V1.1 placeholder)
- About: version, privacy, terms, rate
- Debug (#if DEBUG): wipe data, reseed, stats

### 6.6 Quick Log + Dream Delay Reveal (THE MONEY SHOT)
- QuickLogSheet (.large detent): account → amount → tag → date → log
- DelayedImpactRevealView (.fullScreenCover): orchestrated reveal animation showing delay impact, with backward progress bar and haptic at completion

---

## 7. Core Business Logic

### Delay Calculation

### Smart Suggestions (rotate based on context)
- "Skipping this 4x/month would put your goal 8 days closer"
- "This is 12% of your weekly delay budget"
- "Your [Goal] just slipped to [new estimated date]"

---

## 8. Auth & Sync

- **V1:** Guest-first, no auth, local-only (SwiftData)
- **V1.1+:** Optional Supabase sync (Prompt 10), guest-to-account merge
- **Shared couples mode (V1.1+):** requires account + cloud sync; one partner action
  (log spend / protect amount) syncs to the shared goal and notifies the other partner.
- Sign-in is NEVER required to use the app

---

## 9. Tech Stack

- iOS 17+, SwiftUI only
- Swift 5.9+, @Observable macro
- SwiftData for persistence
- No third-party libraries in V1
- System SF Pro fonts only
- RevenueCat → V1.1 (paywall)
- Supabase → V1.1 (sync)
- Dynamic Island / Live Activities → V1.1

---

## 10. Build Order

1. Project structure + theme tokens
2. Design system (styles, modifiers, catalog)
3. Reusable components (14 total)
4. Onboarding flow
5. Home screen
6. Quick Log + Dream Delay reveal (money shot)
7. Plan + History + Settings screens
8. SwiftData persistence
9. (V1.1) Supabase sync
10. (V1.1) Shared couple goals + partner notifications
11. (V1.1) Voice + Widgets + Paywall

---

## 11. Success Metrics

- **Day 1:** Onboarding completion rate >60%
- **Day 7:** Active users logging ≥3 expenses/week
- **Day 30:** Retention >25%
- **Viral signal:** Users sharing screenshots of DelayedImpactCard
