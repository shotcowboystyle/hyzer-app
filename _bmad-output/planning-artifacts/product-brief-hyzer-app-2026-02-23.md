---
stepsCompleted: [1, 2, 3, 4, 5]
inputDocuments:
  - _bmad-output/brainstorming/brainstorming-session-2026-02-23.md
date: 2026-02-23
author: shotcowboystyle
---

# Product Brief: hyzer-app

## Executive Summary

Hyzer is a native iOS and Apple Watch disc golf scorecard built for a friend group. Its design principle is simple: **score without stopping.** Voice-powered input lets a scorekeeper record an entire hole -- "Mike 3, Jake 4, Sarah 2" -- without breaking stride. Any participant can score for anyone, eliminating the designated scorekeeper burden. A purpose-built Watch companion puts live standings on your wrist with Crown-based score entry. And fluid, momentum-driven animations make every leaderboard shift feel like the competitive moment it is.

Hyzer runs on CloudKit's free tier with zero infrastructure cost. It ships via TestFlight to a small group -- no App Store, no subscriptions, no bloat. It's also an intentional engineering and design playground: a vehicle for exploring Apple-native development, offline-first sync, rich motion design, and novel interaction patterns that commercial apps can't risk.

---

## Core Vision

### Problem Statement

Disc golf scoring for casual friend groups is unnecessarily painful. Commercial apps charge subscription fees for features a friend group will never use. The scoring experience itself creates a social imbalance -- one person gets stuck as the designated scorekeeper, manually entering scores for every player on every hole while everyone else just plays. And the act of scoring interrupts the game: stop walking, pull out the phone, unlock, navigate, tap, tap, tap, put it away. The alternatives (mental math, paper) lose data the moment the round ends.

### Problem Impact

The scoring interruption compounds over 18 holes. The designated scorekeeper is the least present player in the group -- always a few steps behind, always looking at a screen. Over time, it discourages tracking scores at all, and the group loses the competitive history and friendly rivalries that make the game more fun. The problem isn't that scoring is hard. It's that scoring *stops the game*.

### Why Existing Solutions Fall Short

Existing disc golf apps (UDisc, etc.) are built as commercial products for a broad market. They bundle course maps, stats dashboards, community features, and tournament tools behind paywalls. For a friend group that just wants to keep score and see who won last Thursday, the value proposition doesn't hold. More critically, they all inherit the same mental model from paper scorecards: one device, one scorekeeper, manual tap-by-tap entry. None of them solve the interruption problem because they've never questioned the assumption that scoring requires stopping.

### Proposed Solution

Hyzer is a native Swift/SwiftUI app for iPhone and Apple Watch, distributed via TestFlight. It tracks live scores during rounds with real-time sync across all participants' devices via CloudKit at zero cost. Three input paradigms, each optimized for a different moment during a round:

- **Voice** (phone or Watch): A context-aware micro-language -- "Mike 3, Jake 4, Sarah 2" -- that works because the app already knows the round, the hole, and the players. No commands, no qualifiers, just names and numbers.
- **Crown** (Watch): Physical rotation anchored at par for the current hole. One tick down for birdie, one up for bogey. Haptic confirmation.
- **Tap** (phone): Inline picker for deliberate, screen-based entry when you want it.

Any player can enter scores for any other player, distributing the scorekeeper role across the group. The Watch companion is a purpose-built leaderboard -- not a shrunken phone app -- with fluid animations that make every standings change feel like the competitive moment it is.

### Key Differentiators

- **"Score without stopping"**: The entire app serves one purpose -- scoring that doesn't interrupt the game
- **Voice micro-language**: Context-aware input reduced to the atoms (name + number) because the app knows everything else. Not possible in general-purpose apps that serve strangers.
- **Three input paradigms**: Voice, Crown, and Tap -- each designed for a different physical context during a round
- **Distributed scoring**: Any participant scores for anyone. No more designated scorekeeper.
- **Momentum-driven animation**: Every transition -- leaderboard reshuffles, score entries, state changes -- animated with fluid motion that reinforces forward movement. Animation is the competitive payoff, not decoration.
- **Zero cost, zero bloat**: CloudKit free tier, TestFlight distribution, no accounts, no ads, no features that don't serve scoring
- **Design playground**: A personal sandbox for bold interaction design and Apple-native experimentation that commercial apps can't risk

---

## Target Users

### Primary Users

**The Friend Group Player** (all 6 members)

**Profile:** Tech-comfortable adults who play disc golf together weekly (~50+ rounds/year). All equally invested in the game. Two are programmers; all can pick up a new app without hand-holding. Organized via group text -- low-ceremony, day-of coordination. Competitive in the moment (trash talk, celebrating good throws) but not stat-obsessed between rounds. A few have Apple Watches; most are phone-only. Local courses vary between 9 and 18 holes -- a quick 9-hole round might be a weekday lunch break, while a full 18 is a Saturday morning commitment. The app treats both the same mechanically, but the emotional weight of a round summary differs.

There are no secondary users. Every participant is a peer with equal access and equal authority. This is a closed friend-group app with no admins, stakeholders, or external influencers.

**Persona -- "Nate"**

Nate plays disc golf weekly with the same 5 friends. He knows how to use apps but doesn't want to think about them during a round. He's there for the throws, the trash talk, and the outdoors. When someone has to keep score, he'll do it -- but he'd rather not be tapping a phone while everyone else is already walking to the next tee.

Nate operates in two modes:

- **On-course Nate:** Competitive, present, wants zero friction. Scoring should be invisible -- something that happens without stopping the game. He cares about live standings and the banter they fuel.
- **Off-course Nate:** Curious. Opens the app on a Tuesday to scroll through past rounds -- not to analyze trends, but to remember. Who won at Cedar Creek last month? Did I shoot better this time? He's settling friendly debates and revisiting good days with friends. History is memory, not analytics. At 50+ rounds a year, the history view needs to be browsable at scale, not just a short list.

| Attribute | Detail |
|---|---|
| **Motivation** | Stay in the competitive moment with friends without logistical friction |
| **Current workaround** | UDisc sometimes, mental math other times, depends on who volunteers to keep score |
| **Frustration** | Scoring is a chore that falls unevenly on whoever draws the short straw |
| **Success vision** | Score entry is so fast and distributed that nobody notices who's "keeping score" -- because everyone is |

**Situational Role: The Round Organizer**

Not a separate person -- any of the 6 might organize on a given day. The organizer texts the group, picks the course, and on game day starts the round in the app. This role rotates naturally and doesn't need special permissions or UI for scoring -- just the ability to create a round and add the usual players quickly. The organizer has one additional responsibility: resolving score discrepancies when two participants record conflicting scores for the same player on the same hole. For scoring, the organizer is a peer. For conflict resolution, they are the authority.

**Situational Role: The Voice Scorer**

Not a fixed person. Whoever decides to call out scores on a given hole. With voice input, this becomes effortless enough that it might rotate naturally -- one person calls scores on hole 3, someone else on hole 7. The designated scorekeeper problem dissolves because the cost of scoring drops to near zero.

**Boundary Condition: The Guest Player**

Occasionally someone brings a friend to a round. Guests are added as typed names during round creation -- no account, no sign-up, just a string. Guests are round-scoped labels, not persistent identities. They appear on the leaderboard and in round history like any other player, but there is no deduplication, no global guest identity, and no account migration. If "Dave" shows up in two different rounds, they may or may not be the same person -- and nobody cares.

### User Journey

**Discovery:** A group text. "Hey I built a disc golf app for us, here's the TestFlight link." Zero marketing, zero onboarding funnel. Every user is personally invited by the developer.

**Onboarding:** Open the app, enter a display name, done. iCloud identity handles the rest silently. The app ships with 3 local courses already seeded, so there's something to use immediately.

**First Round:** The organizer taps "New Round," picks the course, adds the 5 friends by name. Everyone gets a push notification. Scoring begins -- tap, Crown, or voice. The leaderboard updates live across all devices. Trash talk intensifies when standings shift.

**The "Aha" Moment:** Someone speaks "Mike 3, Jake 4, Sarah 2" -- the Watch or phone briefly displays the parsed scores in a transient confirmation view. A half-second glance confirms it heard right. If correct, it auto-commits after a short timeout. If something's wrong, a single tap corrects the misheard entry. They keep walking. The leaderboard on everyone's device reshuffles with a fluid animation. Nobody stopped. The score just *happened* -- and the scorer *knows* it happened because they saw the confirmation. Trust builds with every use.

**The Ride Home:** Round's over. Everyone's walking to the parking lot or sitting in their car. The app pushes a round complete summary: "Round complete at Cedar Creek. You finished 2nd (+3)." The final standings card is clean, well-animated, satisfying to look at. Someone screenshots it and drops it in the group chat. The round is still warm. This is where the experience lands emotionally -- not on hole 18, but ten minutes later when you see the full picture.

**Between Rounds:** On a Tuesday, Nate opens the app and scrolls through past rounds. Cards show the course, the date, who played, final standings. He remembers that round where he came from behind on the back nine. History isn't a database -- it's a collection of moments with friends.

**Long-term:** The app becomes the default. "Who's keeping score?" stops being a question. Rounds accumulate. The between-round browse becomes a quiet habit. The competitive banter stays on the course, where it belongs.

### Platform Note

Only a few members of the group have an Apple Watch. The Watch experience is a bonus, not a requirement. No flow depends on it -- including voice scoring, which works from the phone in your pocket as well as from the Watch. For the friends who have a Watch, it should feel like a superpower: leaderboard on the wrist, haptic confirmations, Crown scoring. For everyone else, the phone experience is complete on its own.

---

## Success Metrics

### User Success

Success for hyzer-app is adoption, not engagement metrics. The app serves 6 people who already play together weekly. They don't need to be convinced to play disc golf -- they need to be convinced to use *this app* instead of UDisc or mental math.

| Metric | Target | How to measure |
|---|---|---|
| **Group adoption** | All 6 friends install and use the app for at least one round | TestFlight installs + first round participation |
| **Sustained use** | The group uses hyzer-app for a second round without being asked | Organic return -- if they open it again on their own, the app proved itself |
| **UDisc displacement** | The group stops opening UDisc for scoring | Self-evident -- you either reach for hyzer-app or you don't |
| **Smooth experience** | Zero round-breaking bugs during the first 3 rounds | No crashes, no lost scores, no sync failures that require workarounds |
| **"Looks slick"** | At least one friend unprompted comments on the design or animations | Social proof that the visual quality registers |

### Personal / Learning Success

This project is an engineering and design playground. Success is measured by technical milestones achieved, not shipped features counted.

| Milestone | Success criteria |
|---|---|
| **Voice scoring works** | A spoken sentence ("Mike 3, Jake 4, Sarah 2") is parsed and recorded correctly during a real round |
| **One fancy animation ships** | At least one transition (leaderboard reshuffle, score entry, round summary) feels fluid, polished, and intentional |
| **Offline sync works** | A score entered with no connectivity syncs correctly when connectivity returns, without user intervention |
| **Apple-native fluency** | Comfortable working in Swift/SwiftUI, building for Watch, and using CloudKit -- measured by feel, not a checkbox |

### Business Objectives

N/A -- This is a personal project with no revenue model, no growth targets, and no commercial ambitions. The "business case" is: zero infrastructure cost (CloudKit free tier), zero distribution cost (TestFlight), and the learning value of building it.

### Key Performance Indicators

Traditional KPIs don't apply. The following practical indicators replace them:

| Indicator | Signal |
|---|---|
| **MVP viability** | Scores for one complete round are saved and viewable in history. This is the minimum threshold for replacing UDisc. |
| **Group trust** | The group defaults to hyzer-app without discussion. "Who's keeping score?" is answered by opening the app, not by volunteering. |
| **Technical confidence** | You can explain how CloudKit sync, WatchConnectivity, and voice recognition work in your app -- because you built them. |

---

## MVP Scope

### Core Features

**1. Onboarding**
- Display name entry on first launch
- Silent iCloud identity via CloudKit
- 3 seeded local courses available immediately

**2. Course Management**
- Create courses with name, hole count (9 or 18), and par per hole
- Default par 3 for all holes, adjust exceptions
- Edit and delete courses
- Any user can manage courses

**3. Round Management**
- Create a round: select course, add players (accounts + typed guest names)
- Players declared at round start, list is immutable once started
- Round completion: auto-detect (all scores entered) + manual "Finish Round" option
- Incomplete rounds handled gracefully (missing holes recorded as no-score)

**4. Scoring -- Three Input Paradigms**
- **Tap** (phone): Tap player row, inline picker (1-10), select, collapse. Auto-advance to next hole after all scores entered with swipe-back navigation.
- **Voice** (phone + Watch): Speak "Mike 3, Jake 4, Sarah 2." Transient confirmation view displays parsed scores. Auto-commits after timeout. Tap-to-correct on misheard entries.
- **Crown** (Watch): Digital Crown anchored at par for current hole. Haptic tick per increment. Confirm to record.

**5. Live Leaderboard**
- Real-time standings across all devices via CloudKit sync
- Ranked by relative standing (+/- par)
- Partial round standings show holes played count
- Momentum-driven animations on standings changes

**6. Apple Watch Companion**
- Purpose-built leaderboard display (not a shrunken phone app)
- Crown-based score entry
- Voice score entry
- Haptic confirmations
- Bidirectional communication via WatchConnectivity (sendMessage + transferUserInfo fallback)

**7. Real-Time Sync**
- CloudKit-powered sync across all participants' devices
- Offline-first: scores save locally, sync when connectivity returns
- Event-sourced scoring: immutable ScoreEvent records, latest event per {player, hole} wins
- Silent sync for agreement, discrepancy detection for conflicts

**8. Discrepancy Resolution**
- When conflicting scores arrive for the same {player, hole}, round organizer is alerted
- Organizer sees both values, taps the correct one
- Resolution creates a new ScoreEvent that supersedes the conflict

**9. Animations**
- At least one polished, momentum-driven transition (leaderboard reshuffle, score entry, or round summary)
- Animation-first design principle: transitions reinforce forward movement, not decoration
- Celebrate without rubbing it in: neutral visual language for standings changes

### Out of Scope for MVP

| Feature | Rationale |
|---|---|
| **Push notifications** | Round started, round complete, and discrepancy alerts are deferred. Participants discover active rounds by opening the app. Discrepancy alerts surface within the app UI only. |
| **Polished history view** | Scores are saved and persisted. A browsable, card-based history view with rich design comes post-MVP. Minimal "list of past rounds" is acceptable. |
| **Stats and trends** | Deferred. The event-sourced data model supports all future stats as queries over existing data -- zero migration needed. |
| **Scoring attribution** | "Scored by Nate" labels on holes. Novel social dynamic, but not essential for core scoring. |
| **Nearby discovery** | Multipeer Connectivity for round joining. Post-MVP enhancement. |
| **Head-to-head records** | Player-vs-player historical comparisons. Future query over existing data. |
| **Personal bests** | Best round per course, per player. Future query over existing data. |

### MVP Success Criteria

The MVP is validated when:

1. **One complete round** is scored, saved, and viewable by all participants
2. **Voice scoring works** in a real outdoor round -- spoken sentence parsed and recorded correctly
3. **Sync works** -- a score entered offline syncs when connectivity returns
4. **At least one animation** feels fluid and intentional
5. **The group uses it a second time** without being asked

### Future Vision

**Post-MVP Phase 1: Polish**
- Polished round history view with browsable cards (course, date, players, final standings)
- Push notifications (round started, round complete, discrepancy alerts)
- Round complete summary card optimized for screenshots and group chat sharing

**Post-MVP Phase 2: Memory**
- Score trends over time visualization
- Personal bests per course
- Head-to-head records between players
- Scoring attribution ("Scored by Nate" per hole)

**Post-MVP Phase 3: Social**
- Nearby discovery via Multipeer Connectivity for frictionless round joining
- Richer round summary with visual round signature (score trajectory shape)

### Design Principles

- **Score without stopping**: Every feature serves this purpose. If it doesn't, cut it.
- **Momentum-driven animation**: Transitions reinforce forward movement. Nothing bounces, nothing pauses for confirmation dialogs, nothing makes you wait.
- **Celebrate without rubbing it in**: The leaderboard is an emotional amplifier in both directions. The app's visual language stays neutral -- momentum-driven animations, not winner confetti vs. loser slides. Keep the competitive energy in the friend group's trash talk, not in the app's tone.
- **Two distinct UIs, not one responsive UI**: The phone is for input and management. The Watch is for output and minimal input. They share data, not design.
