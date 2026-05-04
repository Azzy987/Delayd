# Delayd — AI Agent Instructions

## Reference Files

- AGENTS.md — AI agent instructions, design philosophy, and implementation rules
- blueprint.md — product concept, flows, and feature scope
- brand-tokens.md — locked brand tokens copied from ~/Downloads/Delayd/logo/brand-tokens.md

Read all three files before generating code.

## What Delayd Is

Delayd is **NOT** an expense tracker. It is a behavior-changing financial app that converts spending into time delay toward personal dreams.

**The core insight:** Every expense delays a goal by X days. Users don't see "₹500 spent" — they see "₹500 delayed your Bali trip by 2 days."

## What Delayd Is NOT

- ❌ A generic expense tracker (do not build SyncSpend, Mint, Money Manager)
- ❌ A budget app with pie charts and category breakdowns
- ❌ A banking app with transactions and balances
- ❌ An income/expense tracker (Delayd does NOT track income)

If a UI suggestion would feel at home in Mint or any generic budget app, it is wrong for Delayd.

## V1 Feature Scope (LOCKED — DO NOT ADD FEATURES)

### IN V1
- ✅ Goal creation with emoji picker (11 presets: ✈️ 🏖️ 📱 🎮 🏠 🚗 🎓 💍 ⚡ 💰 ⭐)
- ✅ Manual expense logging with delay impact reveal
- ✅ Goal progress tracking with backward animation
- ✅ Smart insights (rotating)
- ✅ Settings: monthly savings target, currency, haptics, notifications
- ✅ Light + dark mode
- ✅ Local-first storage (SwiftData)

### NOT IN V1 (deferred)
- ❌ Income tracking
- ❌ Voice input (V1.1)
- ❌ Receipt scanning (V1.2 — Pro feature)
- ❌ Language selection (English only in V1)
- ❌ Account creation / sign-in
- ❌ Cloud sync (Supabase added in Prompt 10, optional)
- ❌ Widgets (V1.1)
- ❌ Live Activities (V1.1)
- ❌ Multiple currencies per goal

If asked to add any of the above, refuse and reference this document.

## Design Philosophy (LOCKED)

**Reference aesthetic:** Paylix-inspired — soft white background, floating cards, purple hero accents.
**Design heroes:** Paylix, Things 3, Cash App, Cluely.
**Anti-heroes:** Mint, generic budget apps, anything with cluttered dashboards or pie charts.

### Visual Language

- Soft off-white background (NOT pure white, NOT gray)
- White floating cards with gentle soft shadows
- Generous whitespace — let the design breathe
- Rounded geometry everywhere (16-24pt radius)
- Sparse use of accent purple — only on key data and hero elements
- Premium typography hierarchy (SF Pro Display + SF Mono for numbers)
- Fixed bottom tab bar with floating "+" button above it

### Color Tokens (LOCKED — DO NOT INVENT NEW VALUES)

**Backgrounds:**
- Light bg: #FAFAFC (soft off-white, not pure white)
- Surface (cards): #FFFFFF
- Dark bg: #0E0A1A
- Dark surface: #1A1530

**Text:**
- Primary (light): #0A0A0F
- Secondary (light): #6B6478
- Tertiary (light): #9B95A8
- Primary (dark): #F8F6FB
- Secondary (dark): #A5A0B5
- Tertiary (dark): #6B6478

**Accent (purple — used sparingly):**
- Primary purple: #7C5CFC
- Hero gradient: #8B6FFF → #6B47E0 (135°, used for goal hero cards)
- Soft purple bg: #EDE7FE (subtle highlights, tag chips)

**Functional:**
- Positive (ahead of schedule): #2DBE7F
- Warning (slightly behind): #FFB84D
- Negative (delay impact): #FF5A6B (use SPARINGLY)
- Soft positive bg: #E5F7EE
- Soft warning bg: #FFF4E1
- Soft negative bg: #FEEAEC

**Special:**
- Insight banner bg: #0A0A0F (premium black with subtle purple glow)
- Insight banner text: #FFFFFF
- Insight banner accent: #8B6FFF

**Goal Category Colors (for emoji backgrounds):**
- Travel (✈️🏖️): #FFE4D4 / accent #FF8C5A
- Tech (📱🎮): #E0E8FF / accent #5A8CFF
- Home (🏠): #FFE4F0 / accent #FF5A9D
- Vehicle (🚗): #E4F5FF / accent #5AB8FF
- Education (🎓): #EDE7FE / accent #7C5CFC
- Wedding (💍): #FCE4FF / accent #C45AFF
- Emergency (⚡): #FFE4E4 / accent #FF5A5A
- Savings (💰): #E5F7EE / accent #2DBE7F
- Custom (⭐): #F5F0FF / accent #8B6FFF

### Typography

- Display: SF Pro Display (system, weight Bold for hero numbers)
- Body: SF Pro Text (system, weight Regular/Medium)
- Numbers/amounts: SF Mono (financial trust signal, weight Medium/Bold)
- All type styles must support Dynamic Type
- Hero number sizes: 48pt (impact card), 32pt (goal card), 24pt (section headers)

### Motion Language

- Forward progress: ease-out, 280ms (optimistic, light)
- Backward progress (delay impact): ease-in-out, 600ms (intentionally slower — feels like loss)
- Card transitions: spring(response: 0.5, dampingFraction: 0.85)
- Sheet presentation: spring(response: 0.4, dampingFraction: 0.8)
- Tab bar: standard SwiftUI behavior
- Floating "+" button: subtle scale on press (0.92), springs back
- NEVER bouncy, NEVER playful

### Spacing & Radius

- Spacing: xs:4, sm:8, md:16, lg:24, xl:32, xxl:48
- Radius: sm:8, md:12, lg:16, xl:24, pill:999
- Card padding: 20pt horizontal, 24pt vertical
- Section spacing: lg (24pt) between sections, md (16pt) within
- Hero card padding: 24pt all sides

### Shadows

- Card shadow: y:4, blur:16, color: black @ 6% opacity (light mode)
- Hero card shadow: y:8, blur:24, color: purple @ 12% opacity
- Floating button shadow: y:8, blur:20, color: purple @ 30% opacity
- Dark mode: reduce all opacities by 50%

## Tab Structure (LOCKED — 4 TABS ONLY)

| Tab | SF Symbol | Purpose |
|-----|-----------|---------|
| Home | house.fill | Active goal, recent impacts, smart insight |
| Plan | target | All goals with progress |
| History | clock.fill | Expense history with delay impacts |
| Settings | gearshape.fill | Currency, monthly target, haptics |

**Floating "+" button** sits ABOVE the tab bar (centered, slightly raised), opens Quick Log sheet from any tab.

**Do NOT add a "Reports" tab.** No pie charts. No category breakdowns as primary content.

## Architecture Rules

- iOS 17+ only, SwiftUI only (no UIKit unless absolutely necessary)
- Use @Observable macro (not ObservableObject)
- SwiftData for persistence (added in Prompt 8 — mock data before that)
- Guest-first: NO sign-in, NO auth, NO accounts in V1
- Local-first: all data on device until Supabase sync (Prompt 10)
- Clean MVVM-lite — no DI containers, no coordinators, no service locators
- No third-party libraries in V1
- System fonts only (SF Pro Display + SF Pro Text + SF Mono)

## Asset Locations

- Master logo: ~/Downloads/Delayd/logo/logo-master.png (purple Receding D)
- Reference images: ~/Downloads/Delayd/app_design/
  - paylix-home.png (primary aesthetic reference)
  - paylix-plan.png (goals tab reference)
  - paylix-settings.png (settings reference)
  - paylix-quick-log.png (logging flow reference)
  - paylix-goal-card.png (goal card with progress reference)
  - paylix-insight-banner.png (premium black banner reference)
- Blueprint: ~/Downloads/Delayd/app_design/blueprint-v1.md
- Brand tokens: ~/Downloads/Delayd/logo/brand-tokens.md
- Local project references: AGENTS.md, blueprint.md, brand-tokens.md

When generating views, COPY assets into Assets.xcassets/ — never reference external paths in code.

### Icons

- **Tab bar / FAB / chunky chrome icons** → Phosphor (Bold weight) SVGs shipped via `Assets.xcassets` as Image Sets with `preserves-vector-representation = true` and `template-rendering-intent = "template"`. Wrapper: `PhosphorIcon(.house, size: 24)`. New icons: download SVG from https://phosphoricons.com (Bold weight) → drop into `Assets.xcassets/ic_<snake_case_name>.imageset/` → add a case to `PhosphorIcon.Name`.
- **Inline / small accent icons** (bell badges, settings rows, status pills) → SF Symbols still allowed and preferred for accessibility/Dynamic Type fidelity.
- Mixing the two is fine. Do NOT add a runtime icon library — the asset-catalog path is the locked solution.

## Preview Workflow (CRITICAL)

The user inspects everything in Xcode Canvas WITHOUT running the simulator.

**Every file must:**
1. Use #Preview macro (iOS 17+, NOT old PreviewProvider)
2. Include light + dark mode previews
3. Render instantly with no missing dependencies

**Two special files exist:**
- DesignCatalog/DesignSystemCatalog.swift — shows all tokens at a glance
- DesignCatalog/DemoHub.swift — NavigationStack to preview every screen

When generating new screens/components, ALWAYS update DemoHub.swift to include them.

## Working Rules

- READ AGENTS.md, blueprint.md, and brand-tokens.md before generating ANY code
- Generate files one at a time, pause for review on long sequences
- Ask before inventing tokens, components, or patterns not in this doc
- If unsure, prefer the cleaner, more restrained choice
- Compile cleanly with zero warnings
- Add #Preview blocks to every view
- Reference Paylix images in ~/Downloads/Delayd/app_design/ when designing layouts

## Apple HIG + SwiftUI Interaction Rules

Use these rules before introducing or changing any modal, toolbar, button, or navigation pattern. They are condensed from Apple Human Interface Guidelines for Sheets, Alerts, Action Sheets, Buttons, Toolbars, Tab Bars, and Modality.

### Modality Choice

- Use a **sheet** only for a narrowly scoped task or rich contextual content that benefits from retaining the parent context. Examples in Delayd: Quick Log, Impact Details, Goal Details, Paywall, Tone picker, Monthly Savings input.
- Use a **confirmation dialog** (`confirmationDialog`) for a small set of choices related to an intentional action. Examples: time filter, currency choice, theme choice, destructive choices with Cancel.
- Use an **alert** sparingly, only for critical information or an important confirmation that needs immediate attention. Do not use alerts merely to present information.
- Avoid stacking sheets when a navigation push, inline expansion, menu, or confirmation dialog would work.
- Avoid sheet scrolling for short action lists. If a choice list is only 2-4 options, prefer confirmation dialog.
- Full-screen covers are reserved for immersive/high-emotion moments: onboarding, the delay impact reveal, and major paywall moments.

### Toolbars & Navigation Bars

- Put view-level actions in the toolbar/navigation bar, not inside scroll content, when they act on the whole screen. Examples: Done, Share, Edit.
- Leading toolbar area: dismissal/back/share when it helps preserve the centered title. Trailing toolbar area: Done, Save, primary contextual action.
- Use standard system actions and SF Symbols where recognizable: `square.and.arrow.up` for Share, `xmark`/Done for dismissal, `trash` for delete.
- Do not overcrowd toolbars. If more than two actions are needed, move secondary actions into a menu or into contextual content.
- Keep navigation titles useful and short; avoid making toolbar text look like a page title.

### Buttons & Actions

- Minimum practical hit region is 44x44 pt.
- Custom buttons must have visible press feedback.
- Use a prominent primary style only for the most likely positive action. Never make destructive actions primary.
- Use destructive role/style for deletes, resets, wipes, and irreversible actions.
- Prefer text when it clarifies intent better than an icon. Prefer familiar icons when the action is universal.

### Tab Bar Rules

- The tab bar is for top-level navigation only, not actions. Delayd’s floating `+` remains the only global action above the tab bar.
- Keep the tab bar visible across top-level tabs so users always know where they are.

### Delayd-Specific Application

- Impact cards open **Impact Details** as a sheet because the content answers “what did this spend do to my dream?” and contains multiple contextual actions.
- Simple selectors should not become custom bottom sheets unless they need custom preview, explanation, input, or rich visual comparison.
- Every modal must have a clear reason to interrupt the current flow and a clear way out.

## Forbidden Patterns

- ❌ Pie charts on Home or as primary content (sparklines OK as supporting elements)
- ❌ Bar charts as primary content
- ❌ "Transaction" framing — always frame as "impact" or "delay"
- ❌ Income tracking, salary categories, paycheck breakdowns
- ❌ Forced sign-in or account creation
- ❌ Bouncy or playful animations
- ❌ Custom fonts (system SF only)
- ❌ Third-party runtime libraries (one carve-out: Lottie for the few hero animations; everything else stays first-party)
- ❌ Neumorphic styles (no soft inset shadows)
- ❌ Pink as primary color (purple only)
- ❌ Bright neon colors
- ❌ Reports tab (no category breakdowns)

## Goal Categories with Emoji Presets

When user creates a goal, show this picker:
1. ✈️ Travel
2. 🏖️ Vacation
3. 📱 Tech
4. 🎮 Gaming
5. 🏠 Home
6. 🚗 Vehicle
7. 🎓 Education
8. 💍 Wedding
9. ⚡ Emergency
10. 💰 Savings
11. ⭐ Custom (user picks any system emoji)

Each emoji has a defined background color (see Color Tokens above) used in the goal card icon.

## Remember

Every screen, every component, every animation must answer: **"Does this make the user feel the consequence of their spending?"**

If the answer is no, redesign it.
