---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-hyzer-app-2026-02-23.md
  - _bmad-output/planning-artifacts/ux-design-specification.md
documentCounts:
  briefs: 1
  research: 0
  brainstorming: 0
  projectDocs: 0
  uxDesign: 1
classification:
  projectType: mobile_app
  domain: sports_recreation
  complexity: medium
  projectContext: greenfield
workflowType: 'prd'
date: 2026-02-24
author: shotcowboystyle
lastEdited: 2026-02-24
editHistory:
  - date: 2026-02-24
    changes: 'Post-validation edits: 8 NFR measurement methods added, 2 user journey scenarios added (offline-first, Watch experience), 3 high-impact FRs clarified (FR2, FR23, FR55), 3 new FRs added (FR12b, FR16b), 7 minor FR refinements'
---

# Product Requirements Document - hyzer-app

**Author:** shotcowboystyle
**Date:** 2026-02-24

## Executive Summary

Hyzer is a native iOS and Apple Watch disc golf scorecard for a closed friend group of 6 players. It solves a specific problem: scoring interrupts the game. Commercial apps replicate the paper scorecard -- one device, one designated scorekeeper, tap-by-tap entry. The scorekeeper is always a step behind, always on their phone, always the least present player. Over 50+ rounds per year, this discourages tracking scores at all, and the group loses the competitive history that makes the game more fun.

Hyzer eliminates the interruption by offering three input paradigms, each designed for a different physical moment during a round: **voice** ("Mike 3, Jake 4, Sarah 2" -- a context-aware micro-language that works because the app already knows the round, hole, and players), **Digital Crown** (physical rotation anchored at par with haptic ticks), and **tap** (inline picker for deliberate screen-based entry). Any participant can score for any other participant, distributing the scorekeeper role across the group. A purpose-built Watch companion puts live standings on the wrist. Momentum-driven animations make every leaderboard reshuffle feel like the competitive moment it is.

The app runs on CloudKit's free tier with zero infrastructure cost. Distribution is via TestFlight -- no App Store, no subscriptions, no accounts beyond iCloud identity. It is also an intentional engineering and design playground for exploring Swift/SwiftUI, offline-first sync, speech recognition, WatchConnectivity, and bold interaction patterns that commercial apps can't risk.

### What Makes This Special

- **Context-aware voice micro-language.** Input reduces to the atoms -- names and numbers -- because the app knows everything else. Not possible in general-purpose apps that serve strangers. This is the defining experience: speak scores, watch the leaderboard shift, keep walking.
- **Distributed scoring.** Any player scores for any player. The designated scorekeeper problem dissolves because the cost of scoring drops to near zero. The group owns the score collectively.
- **Three input paradigms for three physical contexts.** Voice for hands-free batch entry while walking. Crown for wrist-level single-player entry. Tap for deliberate, precise correction. Each fits a different moment in the round's natural rhythm.
- **The leaderboard is the product.** Score entry is infrastructure. The live, animated, synced leaderboard -- and the competitive context it creates across all devices -- is what users care about. The score-to-standings loop is the core experience, repeated 36-108 times per round.
- **Zero cost, zero bloat.** CloudKit free tier, TestFlight distribution, no features that don't serve scoring. Built for 6 people, not a market.

## Project Classification

| Dimension | Classification |
|---|---|
| **Project Type** | Native mobile app (iOS + watchOS), Swift/SwiftUI |
| **Domain** | Sports/Recreation -- casual competitive disc golf scoring |
| **Complexity** | Medium -- technically complex (CloudKit sync, speech recognition, WatchConnectivity, offline-first, multi-device event sourcing) but domain-simple (no regulations, no payments, no compliance) |
| **Project Context** | Greenfield -- new product, no existing codebase |
| **Distribution** | TestFlight to a closed group of 6 users |
| **Infrastructure** | CloudKit free tier -- zero server cost |

## Success Criteria

### User Success

| Metric | Target | Measurement |
|---|---|---|
| **Group adoption** | All 6 friends install and use the app for at least one round | TestFlight installs + first round participation |
| **Sustained use** | The group uses hyzer-app for a second round without being prompted | Organic return -- if they open it again on their own, the app proved itself |
| **UDisc displacement** | The group stops opening UDisc for scoring | Self-evident -- you either reach for hyzer-app or you don't |
| **Smooth experience** | Zero round-breaking bugs during the first 3 rounds | No crashes, no lost scores, no sync failures that require workarounds |
| **Design quality registers** | At least one friend unprompted comments on the design or animations | Social proof that the visual polish is noticeable |

### Business Success

N/A -- This is a personal project with no revenue model, no growth targets, and no commercial ambitions. The business case is: zero infrastructure cost (CloudKit free tier), zero distribution cost (TestFlight), and the learning value of building it.

### Technical Success

| Milestone | Success Criteria |
|---|---|
| **Voice scoring works** | A spoken sentence ("Mike 3, Jake 4, Sarah 2") is parsed and recorded correctly during a real outdoor round with >80% accuracy |
| **Cross-device sync** | A score entered on one device updates the leaderboard on all other devices within 5 seconds on normal connectivity |
| **Offline-first sync** | A score entered with no connectivity syncs correctly when connectivity returns, without user intervention |
| **Voice-to-leaderboard latency** | From end of speech to leaderboard reshuffle animation completing on the scorer's device: <3 seconds |
| **At least one polished animation** | One transition (leaderboard reshuffle, score entry, or round summary) feels fluid, polished, and intentional |
| **Apple-native fluency** | Comfortable working in Swift/SwiftUI, building for Watch, and using CloudKit -- measured by feel, not a checkbox |

### Measurable Outcomes

The MVP is validated when all five conditions are met:

1. **One complete round** is scored, saved, and viewable by all participants
2. **Voice scoring works** in a real outdoor round -- spoken sentence parsed and recorded correctly at >80% accuracy
3. **Sync works** -- scores entered offline sync when connectivity returns; cross-device updates land within 5 seconds
4. **At least one animation** feels fluid and intentional
5. **The group uses it a second time** without being asked

_See [Project Scoping & Phased Development](#project-scoping--phased-development) for complete MVP feature set, post-MVP roadmap, and risk mitigation strategy._

## User Journeys

### Journey 1: Nate's First Round -- From Install to "Aha"

Nate gets a text from his friend: "Built a disc golf app for us, here's the TestFlight link." He taps it, installs, opens the app. One screen: "What should we call you?" He types "Nate," taps done. That's it -- he's in. The home screen shows three familiar local courses already loaded. No tutorial, no walkthrough, no permissions gauntlet.

Saturday morning at Cedar Creek. His buddy starts a round in the app -- picks Cedar Creek, adds the usual five friends by name. Nate's phone shows the round. He taps into it and sees Hole 1: six player rows, all showing dashes. A floating pill at the top reads "1.Nate E  2.Jake E  3.Mike E..." -- everyone tied at even par. The round hasn't started yet and the leaderboard already makes sense.

Hole 1 finishes. Someone taps the mic button and says "Nate 3, Jake 4, Mike 3, Sarah 4, Dave 3, Chris 5." A confirmation overlay flashes the parsed scores -- names and numbers, large and readable. A beat passes. It auto-commits. The dashes on Nate's hole card fill in with numbers. The floating pill at the top pulses -- positions shift. Jake dropped. Chris dropped further. Nate glances at the pill and sees he's tied for first.

Nobody stopped walking. The score just *happened*. Nate didn't keep score, didn't volunteer, didn't even pull out his phone. Someone else spoke everyone's scores and the leaderboard updated on his device. That's the moment -- the thesis proved in real time. The designated scorekeeper doesn't exist anymore.

By hole 5, Nate taps the pill to see the full leaderboard. Rows animate into ranked positions. He's in second, one stroke behind Jake. The trash talk intensifies. By hole 14, he pulls ahead. The pill pulses again. He grins.

Round ends. The app detects all 18 holes scored and prompts "All scores recorded. Finalize round?" One tap. A round summary card slides up -- Cedar Creek, today's date, final standings. Nate finished first at -2. He screenshots it and drops it in the group chat before he reaches the parking lot. The round is still warm.

**What this journey reveals:**
- Onboarding must be instant (one field, no barriers)
- Round discovery must be passive (push or sync, no join codes)
- Voice scoring is the "aha" moment -- must work on first attempt
- Leaderboard pill must update across all devices in real time
- Round summary card must be screenshot-ready
- The emotional arc runs from curiosity (install) to surprise (voice works) to competitive engagement (pill updates) to warm satisfaction (summary card in group chat)

---

### Journey 2: Nate as Voice Scorer -- The Correction Path

Hole 7 at Riverside Park. Nate's walking between tee and basket, phone in his pocket. He decides to call scores this hole. He pulls out his phone, taps the mic on the Hole 7 card, and says "Jake 3, Mike 4, Sarah 3, Dave 5, Chris 3, Nate 3."

The confirmation overlay appears:

```
Jake .... 3
Mike .... 4
Sarah ... 3
Dave .... 5
Chris ... 3
Nate .... 3
```

He glances -- 1.5 seconds to verify. But wait, Dave got a 4, not a 5. He taps "Dave .... 5" and the number becomes an inline picker. One tap: 4. The timer resets. He glances again -- all correct now. The overlay auto-commits. Six ScoreEvents created, synced to everyone's device. The pill pulses. Standings shift.

Total interaction: speak, glance, one correction tap, keep walking. Under 5 seconds. Nate's already talking about his approach shot on Hole 8.

Three holes later, Nate tries voice again on a windy hole. He speaks, but the wind garbles it. The overlay shows two names resolved and one with a "?" -- the parser couldn't match "Shh-ris" to "Chris." Nate taps the unresolved entry, types "Chris" from a quick dropdown of round players, sets the score to 4. Auto-commit. Done.

On Hole 15, the worst case: nothing resolves at all. "Couldn't understand. Try again?" Two buttons: retry (mic re-arms) and cancel (back to the hole card). Nate retries, speaks more clearly, it works. Or he just taps scores manually -- voice failure degrades gracefully to tap, never to a dead end.

**What this journey reveals:**
- Voice confirmation overlay must be large and glance-readable
- Tap-to-correct must be single-tap for the common case (wrong number)
- Unresolved names need a quick player picker, not free text
- Complete parse failure needs retry + cancel, never a blocking error
- Voice failure must degrade to tap seamlessly -- never block scoring
- The correction path must be fast enough that trust builds over time, not breaks on first failure

---

### Journey 3: Nate as Round Organizer -- Setup and Conflict Resolution

Thursday afternoon. Nate texts the group: "Cedar Creek at 4?" Confirmations roll in. At 3:55 he opens the app and taps "New Round." Course list appears -- Cedar Creek is right there (seeded). He taps it. Hole count and par summary display: 18 holes, all par 3.

Add Players screen. He starts typing "Ja..." and Jake appears instantly. Tap. "Mi..." -- Mike. Tap. Four more names, each found with 2-3 characters. The usual group. Dave's friend Marcus is joining for the first time -- Nate taps "Add Guest," types "Marcus," done. No account, no signup, just a name attached to this round.

Round summary: Cedar Creek, 7 players, 18 holes. "Start Round." One tap. The app creates the round, CloudKit sync begins, and everyone's device picks it up. Hole 1 card appears with seven player rows, all dashes. The pill shows seven names at even par. They're playing.

Hole 9. Jake entered Mike's score as 3. Mike entered his own score as 4. Two ScoreEvents arrive at CloudKit for the same {player, hole} with different values. The system detects the discrepancy. Silent for everyone except Nate -- as round organizer, he gets a badge on the leaderboard pill. He taps it, sees the expanded leaderboard with a discrepancy indicator. Taps through to the resolution view:

**Score Discrepancy -- Mike, Hole 9**

| Score: 3 | Score: 4 |
|---|---|
| Recorded by Jake | Recorded by Mike |
| 2:47 PM | 2:48 PM |

Nate asks the group: "Mike, what'd you get on 9?" Mike says 4. Nate taps the right side. Resolution ScoreEvent created, supersedes both conflicting entries. Badge clears. Everyone's leaderboard updates silently. Nobody else even knew there was a conflict.

**What this journey reveals:**
- Round creation must be fast for repeat groups (search by name, quick add)
- Guest player addition must be zero-friction (typed name, no account)
- Player list must be immutable once started (no mid-round confusion)
- Discrepancy detection must be automatic (event-sourced conflict detection)
- Only the organizer sees conflicts -- no group-wide disruption
- Resolution is one-tap: see both values with attribution, pick the right one
- Resolution creates a new authoritative event, doesn't delete either original
- The social layer (asking Mike) happens off-screen -- the app just presents the choice

---

### Journey 4: Marcus the Guest -- One Round, No Commitment

Marcus has never heard of the app. He's Dave's coworker, joining the group for one round. He doesn't have the app installed. He doesn't need it.

When Nate creates the round and adds "Marcus" as a guest, Marcus becomes a string -- a name on the leaderboard, a row on every hole card. His scores are entered by whoever's scoring that hole, same as everyone else. Voice: "Marcus 4." Tap: tap his row, select 4. He appears on the leaderboard, he shows up in the round summary. His experience of the app is entirely through other people's devices.

Marcus plays a solid round, finishes 3rd. The round summary card that gets dropped in the group chat shows his name and score alongside everyone else. If Marcus joins again next month, Nate types "Marcus" again as a new guest. There's no deduplication, no "is this the same Marcus?" prompt. If he's the same person, the group knows. The app doesn't need to.

If Marcus installs the app someday and becomes a regular, he starts fresh -- display name, iCloud identity, full participant. His guest appearances in past rounds stay as they are: strings in the data, memories in the history. No migration, no account linking, no retroactive identity assignment.

**What this journey reveals:**
- Guest players are round-scoped labels, not persistent identities
- Guests need zero onboarding -- they exist through other people's input
- Guests appear on leaderboard and history identically to account holders
- No deduplication logic needed (and no identity system to support it)
- The boundary between guest and account holder is intentionally unmanaged
- The app serves the social reality: the group knows who Marcus is, the app doesn't need to

---

### Journey 5: Off-Course Nate -- Tuesday Night Browsing

Tuesday evening. Nate's on the couch, half-watching TV. He opens hyzer-app, not to score -- just to browse. The home screen shows no active round. Below, a list of past rounds: cards in reverse chronological order.

He scrolls. Cedar Creek, last Saturday -- the round he won. He taps it. Full standings: Nate 1st at -2, Jake 2nd at -1, Mike and Sarah tied for 3rd. He remembers that birdie on Hole 14 that put him ahead. He taps his own name -- hole-by-hole breakdown appears. Hole 14: 2 (birdie). Hole 16: 4 (bogey that almost cost him). The data matches his memory of the moment.

He scrolls back further. Three weeks ago at Riverside Park. He finished 4th. He taps Jake's name in that round -- Jake shot -3 that day, best round he's seen from him. "Hey Jake, remember that -3 at Riverside?" drops into the group text. Friendly debate ensues.

The history isn't analytics. There are no trend lines, no scoring averages, no "you're improving" notifications. It's a collection of rounds -- each one a card with a course name, a date, and a set of names with numbers. At 50+ rounds per year, the list is long enough to scroll through casually but each card is compact enough to show 3-4 per screen. He's not studying data. He's revisiting moments.

**What this journey reveals:**
- History is a reverse-chronological card feed, not a stats dashboard
- Each card must jog memory without requiring a tap (course, date, winner, your position)
- Progressive disclosure: history list to round detail to player to hole-by-hole
- The emotional register shifts from competitive urgency (on-course) to warm nostalgia (off-course)
- At 50+ rounds/year, the list must perform at scale (pagination, local caching)
- History must feel like a scrapbook, not a spreadsheet
- No stats, trends, or computed insights for MVP -- raw memory browsing only

---

### Scenario 6: Dead Zone -- Offline-First Under Pressure

Hole 7 at Riverside Park. Jake glances at his phone -- no bars. The course dips into a wooded valley with zero cell coverage. He doesn't notice, because nothing changed. He taps Sarah's score (3), taps his own (4). The leaderboard reshuffles. The floating pill updates. The confirmation overlay appears and auto-commits. Everything works exactly as it did on Hole 1 when he had full LTE.

Three holes later, still no signal. Mike speaks: "Mike three, Jake four." The voice overlay parses, displays, auto-commits. The leaderboard updates from local data. A small sync indicator badge sits in the corner -- the only visible sign that scores haven't reached CloudKit yet.

Hole 18. They walk to the parking lot. Jake's phone reconnects. Within seconds, all 11 holes of offline scores sync to CloudKit. Every other player's device picks them up. The leaderboard on Nate's phone -- who had signal the whole time and was scoring from the clubhouse -- merges Jake's scores seamlessly. No duplicates, no conflicts (identical scores from Jake's phone and Nate's manual entries merge silently). The round summary shows all 18 holes, all 7 players, every score intact.

**What this scenario reveals:**
- Offline scoring must be functionally identical to online scoring (NFR10)
- Extended offline periods (up to 4 hours) must recover without data loss (NFR11)
- Sync indicator is the only visible difference between offline and online states
- Scores entered offline by one user and online by another for the same player must merge correctly

---

### Scenario 7: Jake's Wrist -- The Watch Experience

Hole 3. Jake's phone is in his bag. He glances at his Apple Watch -- the hyzer-app complication shows the leaderboard pill: Nate -1, Sarah E, Jake E. He scored a birdie. He taps his name in the Watch leaderboard. The Crown scoring view appears: the current value sits at 3 (par for this hole). He rotates the Digital Crown down one click -- haptic tick -- the display shows 2. He taps confirm. Haptic confirmation pulse. The leaderboard on his wrist reshuffles: Jake -1, tied with Nate.

Hole 9. Jake wants to score for Sarah too. He activates voice on his Watch: "Sarah three, Jake four." The Watch routes the audio to his paired iPhone for speech recognition. The confirmation overlay appears on the Watch face -- Sarah 3, Jake 4. After 3 seconds, auto-commit. Both scores recorded. His phone, still in his bag, handles the CloudKit sync.

Hole 14. Jake's phone is dead -- forgot to charge it. The Watch can't reach the phone. Voice input shows "Phone unavailable" and disappears. Crown input still works: local score entry continues. The Watch queues scores for delivery to the phone. When Jake charges his phone at home, the Watch delivers all queued scores, and the phone syncs them to CloudKit.

**What this scenario reveals:**
- Watch leaderboard is a standalone live display, not a phone mirror
- Crown input is the primary Watch scoring method: anchored at par, haptic per increment
- Watch voice routes to phone for recognition; falls back to Crown when phone unreachable
- Watch-to-phone score delivery must be guaranteed even with connectivity loss (NFR12)
- Watch never talks to CloudKit directly -- phone is the sync node

---

### Journey Requirements Summary

| Journey | Key Capabilities Revealed |
|---|---|
| **First Round** | Instant onboarding, passive round discovery, voice scoring, real-time leaderboard sync, round summary card |
| **Voice Correction** | Confirmation overlay, tap-to-correct, unresolved name handling, graceful degradation to tap, retry/cancel on total failure |
| **Round Organizer** | Fast round creation, player search, guest addition, discrepancy detection, one-tap resolution, organizer-only alerts |
| **Guest Player** | Zero-friction guest names, round-scoped identity, no account system, no deduplication |
| **History Browsing** | Reverse-chronological feed, card-based previews, progressive disclosure, scale at 50+ rounds/year, warm visual register |
| **Dead Zone (Offline)** | Offline scoring parity, extended offline recovery, sync indicator as only difference, cross-device merge after reconnect |
| **Watch Experience** | Watch leaderboard display, Crown scoring anchored at par, Watch voice routed to phone, graceful fallback when phone unreachable, guaranteed score delivery |

**Coverage check:**
- Primary user, happy path (Journey 1)
- Primary user, edge case / error recovery (Journey 2)
- Organizer role (Journey 3)
- Guest / boundary condition (Journey 4)
- Off-course / secondary use case (Journey 5)
- Offline-first / connectivity edge case (Scenario 6)
- Watch companion / alternate device (Scenario 7)
- No admin, API, or support user types exist for this product -- all participants are peers

## Innovation & Novel Patterns

### Detected Innovation Areas

**1. Context-Aware Voice Micro-Language (Novel)**

The most innovative pattern in hyzer. Speech recognition for data entry isn't new, but the reduction of voice input to its minimum atoms -- names and numbers only -- is a novel interaction pattern enabled by a unique constraint: the app serves a known, closed group playing a structured game. The app already knows the round, the hole, and the player list, so the voice input needs only the information the app can't infer.

This pattern is not transferable to general-purpose scoring apps that serve strangers. It works specifically because:
- Player names are a known, small set (4-7 per round)
- The current hole is tracked contextually
- Score range is small and predictable (1-10, centered around par)
- Fuzzy name matching against a small known list has high accuracy

**2. Distributed Scoring as Social Design (Novel)**

Existing scoring apps replicate the paper scorecard model: one device, one scorekeeper, sequential entry. Hyzer challenges this assumption by making scoring so cheap (voice: one sentence; Crown: one flick; tap: two taps) that the designated scorekeeper role dissolves naturally. Any participant can enter scores for any other participant.

This is a social interaction innovation, not a technical one. The technical implementation (event-sourced ScoreEvents, last-writer-wins with organizer arbitration for conflicts) enables the social model but isn't itself novel.

**3. Multi-Paradigm Input for a Single Atomic Action (Adapted)**

Three physically distinct input methods -- voice (speak), Crown (rotate), tap (touch) -- each optimized for a different body position during a disc golf round. All three produce the same data artifact (ScoreEvent). The paradigm selection is contextual: voice for batch entry while walking, Crown for single-player entry from the wrist, tap for deliberate correction. No existing scoring app offers more than one input paradigm.

### Validation Approach

| Innovation | Validation Method | Success Signal |
|---|---|---|
| **Voice micro-language** | Real outdoor round with the friend group. Measure parse accuracy across 18 holes in varying conditions (wind, distance from mic, background conversation). | >80% correct parse rate without correction. Group continues using voice after first round. |
| **Distributed scoring** | Observe whether multiple people enter scores during a single round without coordination. | By round 3, no one asks "who's keeping score?" -- multiple participants enter scores naturally. |
| **Multi-paradigm input** | Track which input methods are used per hole across the first 3 rounds. | At least 2 of 3 paradigms see organic use. Users self-select the paradigm that fits the moment. |

### Risk Mitigation

Each innovation has a graceful fallback. Voice degrades to tap, distributed scoring self-organizes to one scorer if needed, Crown is optional for Watch users. See [Risk Mitigation Strategy](#risk-mitigation-strategy) for the full technical risk matrix with likelihood, impact, and mitigation details.

## Mobile App Specific Requirements

### Project-Type Overview

Native iOS + watchOS application built with Swift and SwiftUI. Two distinct apps sharing a CloudKit data layer -- an iPhone app (primary input hub, round management, history) and an Apple Watch app (purpose-built leaderboard, Crown/voice input). Distributed via TestFlight to a closed group. No App Store submission planned for MVP.

### Platform Requirements

| Dimension | Specification |
|---|---|
| **iPhone** | iOS 18+, SwiftUI, SwiftData for local persistence |
| **Apple Watch** | watchOS 11+, SwiftUI, WatchConnectivity for phone communication |
| **Language** | Swift 6 with strict concurrency |
| **UI Framework** | SwiftUI (no UIKit except where SwiftUI lacks capability) |
| **Local Persistence** | SwiftData (replaces Core Data) |
| **Cloud Sync** | CloudKit (public database for shared data, free tier) |
| **Architecture** | MVVM with SwiftUI's native observation (`@Observable` macro, iOS 17+) |
| **Minimum Devices** | iPhone (any model running iOS 18), Apple Watch Series 6+ (watchOS 11) |

Targeting latest OS versions (iOS 18 / watchOS 11) unlocks:
- `@Observable` macro for clean view model patterns
- SwiftData with CloudKit integration
- Improved `ScrollViewReader` and `TabView` APIs
- `SFSpeechRecognizer` on-device recognition improvements
- watchOS 11 navigation and layout refinements

### Device Permissions & Capabilities

| Permission | Usage | Fallback if Denied |
|---|---|---|
| **Speech Recognition** | Voice scoring ("Mike 3, Jake 4, Sarah 2") | Tap and Crown input remain fully functional. Voice button hidden or disabled. |
| **Microphone** | Audio capture for speech recognition | Same as speech recognition denial. |
| **iCloud / CloudKit** | Cross-device sync, player identity, shared data | App works in local-only mode. Scores save to SwiftData. Banner suggests signing in. |
| **Network** | CloudKit sync, no other network usage | Offline-first by design. Scores sync when connectivity returns. |

No camera, location, contacts, notifications (MVP), Bluetooth, or health data permissions required.

### Offline Mode Strategy

| Concern | Approach |
|---|---|
| **Architecture** | Offline-first. SwiftData is the source of truth. CloudKit is the distribution channel. |
| **Score entry** | All three input paradigms write to SwiftData immediately. No network dependency. |
| **Sync model** | Event-sourced. Immutable ScoreEvent records. Latest event per {player, hole} wins. CloudKit subscriptions push changes to other devices. |
| **Conflict handling** | Matching scores merge silently. Conflicting scores surface to round organizer for resolution. Resolution creates a new authoritative ScoreEvent. |
| **Offline indicator** | Small cloud-slash icon in toolbar. Non-intrusive, persistent while offline. Clears when sync completes. |
| **First launch** | CloudKit unavailability doesn't block onboarding. Seeded courses load from app bundle. Player record saves locally, syncs later. |
| **Watch connectivity** | Watch sends ScoreEvents to phone via `WatchConnectivity.sendMessage` (instant when both active) with `transferUserInfo` fallback (guaranteed delivery). Phone is the CloudKit sync node -- Watch never talks to CloudKit directly. |

### Push Notification Strategy

Deferred to post-MVP. MVP relies on:
- CloudKit subscription-based sync (silent background updates)
- In-app discovery of active rounds
- In-app discrepancy alerts (organizer only)

Post-MVP push notifications planned for: round started, round complete, discrepancy alerts.

### Store Compliance

TestFlight distribution only. No App Store review process for MVP.

| Consideration | Status |
|---|---|
| **App Store Review** | Not applicable -- TestFlight only |
| **Privacy Policy** | Not required for TestFlight among friends |
| **App Tracking Transparency** | No tracking, no ATT prompt needed |
| **In-App Purchases** | None |
| **Export Compliance** | No encryption beyond Apple's standard HTTPS/CloudKit |
| **Content Ratings** | Not applicable |

If App Store submission is pursued post-MVP, standard review compliance would be needed (privacy policy, app description, screenshots).

### Implementation Considerations

**SwiftUI Architecture:**
- Card stack scoring: `TabView(.page)` for horizontal hole paging
- Floating leaderboard pill: `ZStack` overlay with `.ultraThinMaterial`
- Expanded leaderboard: `.sheet` with animated row reordering
- Crown input: `.digitalCrownRotation` binding anchored at par
- Voice input: `SFSpeechRecognizer` with on-device recognition
- Navigation: `NavigationStack` + `TabView` (3 tabs: Scoring, History, Courses)

**Watch Architecture:**
- Leaderboard-first layout, one navigation level deep maximum
- Crown rotation for score entry, voice as secondary input
- `WatchConnectivity` bidirectional communication with phone
- Simpler animations than phone (battery-conscious)

**Data Flow:**
- SwiftData models with CloudKit automatic sync (SwiftData + CloudKit integration)
- ScoreEvent as the atomic data unit across all input paradigms
- Standings computed reactively from ScoreEvents via `@Query`
- Phone is the CloudKit sync node; Watch communicates through phone

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Experience MVP -- the minimum feature set that delivers the defining experience (voice-to-leaderboard loop) in a real round. This is not a feature-reduction exercise; it's a "what proves the thesis?" exercise. The thesis is: scoring shouldn't stop the game. Voice scoring is the proof.

**Resource Requirements:** Solo developer (the product creator). Swift/SwiftUI, CloudKit, WatchConnectivity, SFSpeechRecognizer. No backend infrastructure. No design team -- SwiftUI defaults with a focused custom layer (color system, leaderboard animation, voice overlay).

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**
- Journey 1: First Round (install to onboarding to scoring to summary)
- Journey 2: Voice Scoring with correction path
- Journey 3: Round Organizer (creation + discrepancy resolution)
- Journey 4: Guest Player (round-scoped name)
- Journey 5: History Browsing (minimal -- list of past rounds, not polished cards)

**Must-Have Capabilities:**

| Capability | Justification |
|---|---|
| **Onboarding** (name entry, iCloud identity, seeded courses) | Without it, nobody can use the app |
| **Course management** (create/edit/delete, hole count, par per hole) | Without it, no rounds can be created |
| **Round creation** (select course, add players + guests, start) | Without it, no scoring can happen |
| **Tap scoring** (inline picker, anchored at par) | The reliable fallback. Must work perfectly. |
| **Voice scoring** (micro-language, confirmation overlay, auto-commit, tap-to-correct) | The defining experience. The thesis proof. |
| **Crown scoring** (Digital Crown anchored at par, haptic ticks) | The Watch superpower. Completes the three-paradigm promise. |
| **Live leaderboard** (floating pill + expanded view, real-time sync) | The product IS the leaderboard. Without it, scores are just numbers. |
| **Apple Watch companion** (leaderboard display, Crown + voice input) | Promised as a first-class experience. Watch owners expect it from day one. |
| **CloudKit sync** (offline-first, event-sourced, cross-device) | Without sync, it's a single-device scorecard -- no better than UDisc. |
| **Discrepancy resolution** (organizer-only, one-tap) | Distributed scoring creates conflicts. Without resolution, trust breaks. |
| **Round completion** (auto-detect + manual finish, basic summary) | The round must end cleanly. Summary can be minimal for MVP. |
| **Basic history** (list of past rounds, tap for detail) | Scores must persist and be browsable. Rich card design is post-MVP. |

**Explicitly NOT in MVP:**

| Feature | Why Deferred |
|---|---|
| Push notifications | Round discovery works via app open + CloudKit sync. Notifications add complexity without changing the core experience. |
| Polished history cards | A basic list of past rounds with detail view is sufficient. Rich card design, warm visual treatment is post-MVP polish. |
| Round summary screenshot optimization | A clean summary view ships in MVP. Screenshot-optimized layout with sharing affordances is post-MVP. |
| Stats, trends, personal bests | The event-sourced data model supports all future stats as queries over existing data. Zero migration needed when added. |
| Scoring attribution ("Scored by Nate") | Novel social dynamic but not essential for core scoring. Can be added without data model changes. |
| Repeat group quick-add | "Play with the same group as last time?" is convenience, not necessity. Player search by name is fast enough for MVP. |

### Post-MVP Features

**Phase 2: Polish**
- Polished round history view with browsable cards (course, date, players, final standings)
- Push notifications (round started, round complete, discrepancy alerts)
- Round summary card optimized for screenshot sharing
- Repeat group quick-add for round creation
- Scoring attribution display

**Phase 3: Memory**
- Score trends over time visualization
- Personal bests per course
- Head-to-head records between players

**Phase 4: Social**
- Nearby discovery via Multipeer Connectivity
- Richer round summary with visual round signature

### Risk Mitigation Strategy

**Technical Risks:**

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Voice accuracy <80% outdoors | Medium | High -- group abandons voice permanently | Fuzzy matching, confirmation overlay, tap-to-correct. Voice degrades gracefully to tap. Test in real outdoor conditions early. |
| CloudKit sync latency >5s | Low | Medium -- leaderboard feels sluggish | CloudKit subscriptions for push-based sync. Local-first means scoring is never blocked. Acceptable degradation: leaderboard updates on next app foreground if push fails. |
| SwiftData + CloudKit integration issues | Medium | High -- sync is the core feature | Prototype sync early. SwiftData + CloudKit is relatively new. Have a fallback plan to use raw CloudKit APIs if SwiftData integration is unreliable. |
| WatchConnectivity reliability | Low-Medium | Medium -- Watch scoring fails silently | `sendMessage` for active sessions, `transferUserInfo` for guaranteed delivery. Test both paths. Watch can display stale data gracefully. |
| SFSpeechRecognizer on-device accuracy | Medium | Medium -- affects voice parse rate | On-device recognition (iOS 18) avoids network dependency. Fuzzy matching compensates for recognition errors. Test with real names of the 6 friends. |

**Market Risks:**

Not applicable in the traditional sense. The "market" is 6 known people. The risk is adoption rejection: the group tries it once and goes back to UDisc or mental math. Mitigation: the MVP must work flawlessly for one complete round. Zero crashes, zero lost scores, zero sync failures.

**Resource Risks:**

| Risk | Mitigation |
|---|---|
| Solo developer bandwidth | Lean MVP scope. SwiftUI defaults reduce UI work. CloudKit eliminates backend work. Focus on the scoring loop first, polish everything else later. |
| Scope creep during development | The MVP feature list above is the contract. If it's not on the list, it doesn't ship in v1. |
| Technical learning curve (CloudKit, WatchConnectivity, SFSpeechRecognizer) | Build vertical slices: one hole scored via voice, synced to one other device, displayed on Watch. Prove the full stack works before building breadth. |

## Functional Requirements

### Onboarding & Identity

- **FR1:** A new user can enter a display name on first launch to create their identity
- **FR2:** On first launch, the system reads the user's iCloud account identifier and stores it as the canonical player identity. If iCloud is unavailable, identity creation succeeds locally and the iCloud association is deferred until available.
- **FR3:** A new user can access pre-seeded local courses immediately after onboarding
- **FR4:** A user can complete onboarding without an active network connection

### Course Management

- **FR5:** A user can create a course with a name, hole count (9 or 18), and par per hole
- **FR6:** A user can set a default par (3) for all holes and adjust individual exceptions
- **FR7:** A user can edit an existing course's name, hole count, and par values
- **FR8:** A user can delete a course
- **FR9:** The system does not restrict course creation, editing, or deletion to any user role; all authenticated users have equal access to all course management operations (FR5-FR8)

### Round Management

- **FR10:** A user can create a new round by selecting a course
- **FR11:** A user can add registered players to a round by searching by display name
- **FR12:** A user can add guest players to a round by typing a name (no account required)
- **FR12b:** Guest players are round-scoped labels with no persistent identity across rounds. The system does not deduplicate guest names -- a guest named "Marcus" in two different rounds exists as two independent entries with no linkage.
- **FR13:** Once a round is started, the system prevents adding or removing players. Add-player and remove-player controls are hidden on the active round view, and the data layer rejects player list mutations for active rounds.
- **FR14:** The system can auto-detect round completion when all players have scores for all holes
- **FR15:** A user can manually finish a round at any point, with missing holes recorded as no-score
- **FR16:** The system designates the round creator as the round organizer
- **FR16b:** The system displays active rounds that include the current user as a participant, automatically updated via sync. When a round is created and the user is added as a player, the round appears in their active round list without manual action.

### Scoring: Tap Input

- **FR17:** A user can tap a player row on the current hole to select a score value between 1 and 10, defaulting to par
- **FR18:** The score picker defaults to the par value for the current hole
- **FR19:** A user can tap a previously scored player row to correct their score
- **FR20:** The system auto-advances to the next hole after a brief delay when all players have scores for the current hole. Users can swipe back to the previous hole to review or correct scores.

### Scoring: Voice Input

- **FR21:** A user can activate voice input from the current hole's scoring view
- **FR22:** The system can parse a spoken sentence containing player names and scores against the known player list for the active round
- **FR23:** The system matches spoken name fragments to the known player list using phonetic similarity. A match is accepted when exactly one player scores above the similarity threshold. Ambiguous matches (multiple candidates) surface as unresolved per FR27.
- **FR24:** The system displays parsed scores in a transient confirmation overlay for verification
- **FR25:** The system auto-commits parsed scores after a 3-second timeout if no correction is made. The timeout resets if the user taps any entry. Not user-configurable in MVP.
- **FR26:** A user can tap any entry in the confirmation overlay to correct a misheard score
- **FR27:** The system can handle partial voice recognition (some names resolved, others unresolved)
- **FR28:** The system provides a retry and cancel option when voice recognition fails completely
- **FR29:** Voice input can record scores for all players or a subset in a single utterance

### Scoring: Crown Input (Watch)

- **FR30:** A Watch user can select a player from the leaderboard to enter their score
- **FR31:** A Watch user can adjust a score value using Digital Crown rotation anchored at par
- **FR32:** The system provides haptic feedback for each Crown increment
- **FR33:** A Watch user can confirm a Crown-entered score to record it
- **FR34:** A Watch user can cancel Crown input without recording a score

### Scoring: Cross-Cutting

- **FR35:** Any participant can enter scores for any other participant in the round
- **FR36:** Each score entry creates an immutable ScoreEvent record
- **FR37:** A score correction creates a new ScoreEvent that supersedes the previous one (no destructive edits)
- **FR38:** A user can navigate to any previous hole to view or correct scores

### Live Leaderboard

- **FR39:** The system computes and displays real-time standings ranked by relative score to par
- **FR40:** The system displays a persistent condensed leaderboard (floating pill) during active rounds
- **FR41:** A user can expand the condensed leaderboard to view full standings with detailed player information
- **FR42:** The leaderboard animates position changes when standings shift, with rows sliding to new ranked positions within the animation budget defined by NFR6
- **FR43:** The leaderboard displays partial round standings with holes-played count for each player

### Real-Time Sync

- **FR44:** The system syncs score data across all participants' devices via CloudKit
- **FR45:** The system saves all scores locally before attempting cloud sync (offline-first)
- **FR46:** The system syncs locally-saved scores when network connectivity returns
- **FR47:** The system silently merges matching scores from two or more devices
- **FR48:** The system detects score discrepancies when conflicting ScoreEvents arrive for the same player and hole

### Discrepancy Resolution

- **FR49:** The system alerts only the round organizer when a score discrepancy is detected
- **FR50:** The round organizer can view both conflicting scores with attribution (who recorded each)
- **FR51:** The round organizer can resolve a discrepancy by selecting the correct score with a single tap
- **FR52:** A discrepancy resolution creates a new authoritative ScoreEvent that supersedes both conflicting entries

### Apple Watch Companion

- **FR53:** The Watch app displays a purpose-built leaderboard showing current standings
- **FR54:** The Watch app supports Crown-based score entry
- **FR55:** The Watch app supports voice score entry using the same micro-language as FR22. Speech recognition runs on the paired iPhone via Watch-to-phone communication, with the Watch displaying the confirmation overlay (FR24) locally. If the phone is unreachable, voice input is unavailable and the system falls back to Crown input (FR30-FR34).
- **FR56:** The Watch app communicates score data to the phone bidirectionally
- **FR57:** The Watch app provides haptic confirmations for score actions

### Round Completion & History

- **FR58:** The system displays a round summary with final standings upon round completion
- **FR59:** A user can view a list of past completed rounds in reverse chronological order
- **FR60:** A user can tap a past round to view full final standings
- **FR61:** A user can tap a player in a past round to view their hole-by-hole breakdown
- **FR62:** The system persists all round data indefinitely for browsing, including: round metadata (course, date, players), all ScoreEvents (including superseded corrections and resolutions), and final computed standings. Data is never automatically deleted or expired.

## Non-Functional Requirements

### Performance

| NFR | Requirement | Rationale |
|---|---|---|
| **NFR1** | Voice-to-leaderboard: from end of speech to leaderboard reshuffle completing on the scorer's device in <3 seconds | The "magic" moment. Delay breaks the "it just works" feeling. |
| **NFR2** | Cross-device sync: from score entry on one device to leaderboard update on all other devices in <5 seconds on normal connectivity | The shared competitive moment requires near-simultaneous awareness. |
| **NFR3** | Tap score entry: from picker selection to picker collapse and score display in <100ms | Immediate feedback is a core design principle. No perceived lag on direct interaction. |
| **NFR4** | Crown increment: haptic tick within 50ms of each Crown detent | Physical input must feel mechanically responsive. Delayed haptics break the illusion of direct manipulation. |
| **NFR5** | App launch to active round view in <2 seconds on subsequent launches | Mid-round, users reopen the app to check standings. Must be instant. |
| **NFR6** | Leaderboard reshuffle animation completes in <500ms | No animation exceeds 500ms. The user is walking. |
| **NFR7** | Voice confirmation overlay appears within 500ms of speech completion | The gap between speaking and seeing parsed scores must feel immediate. |

### Reliability

| NFR | Requirement | Rationale |
|---|---|---|
| **NFR8** | Zero score data loss under any connectivity condition. Verified by offline-to-online round-trip test: score count and content assertion confirms all scores entered offline appear identically after sync completes. | Scores saved locally before any sync attempt. Local persistence is the source of truth. A lost score destroys trust permanently. |
| **NFR9** | Zero crashes during active rounds, measured by Xcode crash logs across the first 10 real rounds (minimum 180 scored holes). Any crash during an active round is a release-blocking defect. | A mid-round crash is the worst possible failure mode. All 6 users are present and watching. |
| **NFR10** | Offline scoring parity: all three input paradigms (tap, voice, Crown) function identically offline and online. Leaderboard updates from local scores, confirmation overlays display, auto-advance triggers, and score corrections work without network. Only difference: a sync indicator badge is visible when offline. Verified by completing a full 18-hole round in airplane mode with all three input methods. | Users shouldn't know or care whether they have connectivity. Scoring works the same either way. |
| **NFR11** | CloudKit sync recovery after extended offline period (up to 4 hours) without data loss or duplication. Verified by simulated 4-hour offline period: score count assertion on reconnect confirms all scores present with no duplicates across all participant devices. | A full 18-hole round at a course with no signal, followed by driving home and syncing. Must recover cleanly. |
| **NFR12** | Watch-to-phone score delivery is guaranteed with automatic fallback when real-time communication is unavailable. 100% delivery rate verified by test across 50+ Watch-originated scores with simulated connectivity interruptions (phone backgrounded, Bluetooth range loss, Watch-only mode). | Watch scores must never silently disappear. |

### Accessibility

| NFR | Requirement | Rationale |
|---|---|---|
| **NFR13** | All text meets minimum 4.5:1 contrast ratio against backgrounds (WCAG AA) | Outdoor readability in mixed lighting conditions. Also serves accessibility compliance. |
| **NFR14** | All interactive elements meet 44pt minimum touch target (48pt+ for primary scoring controls) | One-handed, walking-pace interaction. Generous targets for outdoor use. |
| **NFR15** | All custom animations respect `accessibilityReduceMotion` system setting | Animations fall back to instant state changes. Feedback is never removed, only the motion. |
| **NFR16** | All screens support Dynamic Type scaling up to Accessibility XXL (AX3) | Layout adapts to larger text without breaking. No clamped font sizes. |
| **NFR17** | All interactive elements have meaningful VoiceOver labels and hints | Leaderboard reads as ranked list. Scores include player name and par context. No decorative elements announced. |
| **NFR18** | Score state information is conveyed by color AND numeric context (not color alone) | "+2" communicates over-par regardless of color perception. Color reinforces but never carries meaning alone. |

### Data Integrity

| NFR | Requirement | Rationale |
|---|---|---|
| **NFR19** | Event-sourced scoring: no ScoreEvent is ever mutated or deleted. Verified by database audit after 10+ rounds showing zero UPDATE or DELETE operations on ScoreEvent records. All corrections and resolutions must create new events only. | Corrections and resolutions create new events. Full audit trail preserved. |
| **NFR20** | Discrepancy detection is deterministic: identical {player, hole, score} from two or more devices always merges silently. Verified by test with 20+ concurrent identical ScoreEvents from multiple devices producing zero false discrepancy alerts. | "Agree silently, disagree loudly." No false conflict alerts. |
| **NFR21** | Round history persists for at least 5 years (250+ rounds) on-device with CloudKit backup. No automatic data expiration or deletion. Verified by storage projection: at 50 rounds/year with average 7 players and 18 holes, total data volume remains under 50MB after 5 years. | At 50+ rounds/year, history is a long-term asset. No data expiration. |
