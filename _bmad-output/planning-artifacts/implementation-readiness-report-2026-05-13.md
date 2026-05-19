---
date: 2026-05-13
project: hyzer-app
scope: post-mvp
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
documents:
  prd: _bmad-output/planning-artifacts/prd.md
  prd_validation: _bmad-output/planning-artifacts/prd-validation-report.md
  architecture: _bmad-output/planning-artifacts/architecture.md
  ux: _bmad-output/planning-artifacts/ux-design-specification.md
  epics_mvp: _bmad-output/planning-artifacts/epics.md
  epics_post_mvp: _bmad-output/planning-artifacts/epics-post-mvp.md
  product_brief: _bmad-output/planning-artifacts/product-brief-hyzer-app-2026-02-23.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-05-13
**Project:** hyzer-app
**Scope:** Post-MVP epics (`epics-post-mvp.md`) — MVP Epics 1–8 already shipped (23/23 stories, 407 tests)

## Step 1: Document Inventory

| Type | File | Size | Modified | Status |
|------|------|------|----------|--------|
| PRD | `prd.md` | 50 KB | 2026-02-26 | Included |
| PRD Validation | `prd-validation-report.md` | 4 KB | 2026-02-26 | Supporting |
| Architecture | `architecture.md` | 105 KB | 2026-02-26 | Included |
| UX Spec | `ux-design-specification.md` | 103 KB | 2026-02-26 | Included |
| Epics (MVP) | `epics.md` | 54 KB | 2026-02-26 | Baseline (shipped) |
| Epics (Post-MVP) | `epics-post-mvp.md` | 43 KB | 2026-05-13 | **Primary subject** |
| Product Brief | `product-brief-hyzer-app-2026-02-23.md` | 19 KB | 2026-02-26 | Context |

**Duplicates:** None.
**Missing:** None of the required document types are missing.

**Notes:**
- `epics-post-mvp.md` is currently untracked in git.
- All planning docs except `epics-post-mvp.md` are pre-MVP-build (2026-02-26). Drift between PRD/UX/Architecture and post-MVP epics is the most likely source of readiness gaps and will be a focus area.

---

## Step 2: PRD Analysis

**Source:** `prd.md` (658 lines, dated 2026-02-24, validation status: Pass 5/5)

### MVP Requirements Inventory (Baseline — already shipped)

- **Functional Requirements:** 64 total (FR1–FR62 with FR12b, FR16b inserts)
  - Onboarding & Identity: FR1–FR4
  - Course Management: FR5–FR9
  - Round Management: FR10–FR16b
  - Tap Input: FR17–FR20
  - Voice Input: FR21–FR29
  - Crown Input (Watch): FR30–FR34
  - Cross-cutting Scoring: FR35–FR38
  - Leaderboard: FR39–FR43
  - Sync: FR44–FR48
  - Discrepancy Resolution: FR49–FR52
  - Watch Companion: FR53–FR57
  - Round Completion & History: FR58–FR62
- **Non-Functional Requirements:** 21 total (NFR1–NFR21)
  - Performance: NFR1–NFR7
  - Reliability: NFR8–NFR12
  - Accessibility: NFR13–NFR18
  - Data Integrity: NFR19–NFR21

### Post-MVP Requirements (Subject of this Assessment)

The PRD does **not** define numbered FRs/NFRs for post-MVP. Post-MVP requirements are stated only as **informal narrative phase bullets** in section "Project Scoping & Phased Development":

#### Phase 2: Polish (post-MVP roadmap)
- P2-1: Polished round history view with browsable cards (course, date, players, final standings)
- P2-2: Push notifications (round started, round complete, discrepancy alerts)
- P2-3: Round summary card optimized for screenshot sharing
- P2-4: Repeat group quick-add for round creation
- P2-5: Scoring attribution display ("Scored by Nate")

#### Phase 3: Memory
- P3-1: Score trends over time visualization
- P3-2: Personal bests per course
- P3-3: Head-to-head records between players

#### Phase 4: Social
- P4-1: Nearby discovery via Multipeer Connectivity
- P4-2: Richer round summary with visual round signature

**Total informal post-MVP requirements: 10** (5 polish + 3 memory + 2 social).

### Supporting PRD Signals for Post-MVP

- **Push notifications** explicitly deferred (line 384–389): "Post-MVP push notifications planned for: round started, round complete, discrepancy alerts."
- **Polished history cards** explicitly deferred (line 466–471).
- **Round summary screenshot optimization** explicitly deferred (line 468).
- **Stats/trends/personal bests** explicitly deferred with note: "The event-sourced data model supports all future stats as queries over existing data. Zero migration needed when added." — This is an important architectural assertion that post-MVP stories will lean on.
- **Scoring attribution** explicitly deferred: "Can be added without data model changes."
- **Repeat group quick-add** explicitly deferred.

### PRD Completeness Assessment (for post-MVP scope)

| Dimension | Status | Notes |
|-----------|--------|-------|
| MVP FRs / NFRs | ✅ Complete | 64 + 21, fully measurable, validated 5/5 |
| Post-MVP FRs | ⚠️ **Informal only** | 10 bullets, no numbering, no acceptance criteria, no NFRs attached |
| Post-MVP NFRs | ❌ **Absent** | No performance, reliability, accessibility, or data-integrity targets specified for any post-MVP feature |
| Post-MVP Success Criteria | ❌ **Absent** | "Measurable Outcomes" section (line 100–107) only validates MVP |
| Post-MVP Journey Coverage | ⚠️ Partial | Journey 5 (off-course history) hints at polish needs; no journeys for push notifications, stats, head-to-head, or nearby discovery |
| Risk Mitigation for Post-MVP | ❌ Absent | Risk matrix (line 491–513) covers MVP technical risks only |
| Architectural Assertions | ✅ Present | "Zero migration needed" for stats is a load-bearing claim that post-MVP epics must respect |

### Critical Findings for Readiness

1. 🔴 **CRITICAL — Post-MVP requirements lack formal specification.** The PRD provides direction but not contract-grade requirements. Any post-MVP epic must either (a) re-derive its requirements with the same rigor as MVP FRs/NFRs, or (b) the PRD must be amended with formal post-MVP FR/NFR numbering before implementation.
2. 🔴 **CRITICAL — No post-MVP NFRs.** Push notification delivery latency, history list scroll performance, sync impact of new attribution data, and accessibility for new screens are all unspecified.
3. 🟡 **WARNING — No post-MVP success criteria.** Without measurable outcomes, "done" is undefined per phase.
4. 🟡 **WARNING — Two post-MVP areas have UX gaps.** Push notifications and nearby discovery have zero journey-level user-experience definition in the PRD.
5. 🟢 **POSITIVE — Architectural foreshadowing exists.** "Event-sourced data model supports all future stats" and "Can be added without data model changes" set explicit non-breaking expectations for post-MVP work.

These findings will be revisited against `epics-post-mvp.md` in Step 5 (Epic & Story Validation) and synthesized in Step 7 (Final Readiness Report).

---

## Step 3: Epic Coverage Validation

**Source:** `epics-post-mvp.md` (649 lines, dated 2026-05-13)

### Epic Inventory (Post-MVP)

| Epic | Title | PMVP-FRs Claimed | PMVP-NFRs Claimed | Stories |
|------|-------|------------------|-------------------|---------|
| 9  | TestFlight Launch Readiness | FR1–FR5 | — | 9.1, 9.2, 9.3 |
| 10 | Round Setup Quick-Add & Scoring Attribution | FR9, FR10 | — | 10.1, 10.2 |
| 11 | Polished History & Shareable Round Summaries | FR6, FR7, FR8 | — | 11.1, 11.2, 11.3 |
| 12 | Push Notifications | FR11, FR12, FR13 | NFR1 | 12.1, 12.2, 12.3 |
| 13 | Long-Term Memory (Trends, Bests, Head-to-Head) | FR14, FR15, FR16 | NFR3, NFR4 | 13.1, 13.2, 13.3 |
| 14 | Nearby Discovery & Visual Round Signature | FR17, FR18 | NFR2 | 14.1, 14.2 |

**Totals:** 6 epics, 16 stories, 18 PMVP-FRs, 4 PMVP-NFRs.

### Coverage Matrix — PRD Phase Bullets → PMVP-FRs

| PRD Phase Bullet | PRD Text | PMVP-FR Mapping | Epic | Status |
|---|---|---|---|---|
| P2-1 | Polished round history view with browsable cards | PMVP-FR6 | Epic 11 (Story 11.1) | ✅ Covered |
| P2-2 (a) | Push: round started | PMVP-FR11 | Epic 12 (Story 12.1) | ✅ Covered |
| P2-2 (b) | Push: round complete | PMVP-FR12 | Epic 12 (Story 12.2) | ✅ Covered |
| P2-2 (c) | Push: discrepancy alerts | PMVP-FR13 | Epic 12 (Story 12.3) | ✅ Covered |
| P2-3 | Round summary card optimized for screenshot sharing | PMVP-FR7, PMVP-FR8 | Epic 11 (Stories 11.2, 11.3) | ✅ Covered |
| P2-4 | Repeat group quick-add for round creation | PMVP-FR9 | Epic 10 (Story 10.1) | ✅ Covered |
| P2-5 | Scoring attribution display | PMVP-FR10 | Epic 10 (Story 10.2) | ✅ Covered |
| P3-1 | Score trends over time visualization | PMVP-FR14 | Epic 13 (Story 13.1) | ✅ Covered |
| P3-2 | Personal bests per course | PMVP-FR15 | Epic 13 (Story 13.2) | ✅ Covered |
| P3-3 | Head-to-head records between players | PMVP-FR16 | Epic 13 (Story 13.3) | ✅ Covered |
| P4-1 | Nearby discovery via Multipeer Connectivity | PMVP-FR17 | Epic 14 (Story 14.1) | ✅ Covered |
| P4-2 | Richer round summary with visual round signature | PMVP-FR18 | Epic 14 (Story 14.2) | ✅ Covered |

**PRD phase-bullet coverage: 12/12 (100%)**

### PMVP-FRs Without Direct PRD Requirement Source

Epic 9 (TestFlight Launch Readiness) maps **PMVP-FR1 through PMVP-FR5** to platform/distribution needs that are referenced in the PRD prose but never formalized as requirements. These were derived from:

| PMVP-FR | Derivation Source | PRD Reference |
|---------|--------------------|---------------|
| PMVP-FR1 | Architecture + standard iOS release practice | PRD line 393 ("TestFlight distribution only") |
| PMVP-FR2 | Apple Privacy Manifest requirement (App Store Connect prerequisite) | Inferred from PRD §"Device Permissions & Capabilities" (line 360–368) |
| PMVP-FR3 | iOS Info.plist required strings for declared permissions | Inferred from PRD line 363–365 (Speech + Microphone usage) |
| PMVP-FR4 | iOS app icon set requirement for TestFlight upload | Not in PRD (platform-mandated) |
| PMVP-FR5 | App Store Connect record needed to enable TestFlight | PRD line 393 ("TestFlight only") implies this |

**Assessment:** These are necessary, defensible epics, but they are **self-derived launch-readiness work without a PRD requirement contract**. The epics file itself flags this transparently in its header ("PMVP requirements were derived from the PRD's Post-MVP roadmap bullets and UX specification components and have not been through the BMAD PRD validation workflow"). This is honest documentation but does represent a traceability weakness.

### PRD NFR Coverage Map (Cross-Cutting from MVP)

Post-MVP work must continue to honor the 21 MVP NFRs. Spot-checking critical ones against post-MVP changes:

| MVP NFR | Risk from Post-MVP | Mitigation in Epics? |
|---------|--------------------|-----------------------|
| NFR5 (launch <2s) | Push registration could slow launch | ✅ Story 12.1 explicitly defers `UNUserNotificationCenter.requestAuthorization` to first round creation (lazy) |
| NFR8 (zero score loss) | Multipeer payload could conflict with CloudKit sync | ⚠️ Story 14.1 limits Multipeer payload to `Round.id + playerIDs` only (no scores) — risk mitigated by scope, but not explicitly tested |
| NFR13 (4.5:1 contrast) | New history/summary/trend views | ✅ Stories 11.1, 11.2, 13.1 all reference NFR13 directly |
| NFR15 (reduce motion) | Round signature animation | ✅ Story 14.2 acceptance criterion explicitly handles reduce motion |
| NFR16 (Dynamic Type AX3) | Scoring attribution text below score | ✅ Story 10.2 acceptance criterion explicitly tests AX3 row growth |
| NFR19 (event sourcing immutable) | Read-side computations (trends/H2H) | ✅ Stories 13.1–13.3 are read-only; Story 10.2 explicitly references supersession chain |
| NFR21 (250+ rounds, 5yr persistence) | History list scroll perf | ✅ PMVP-NFR3 added (scroll <16ms at 250 rounds) |

**Missing NFR re-verification:** NFR1 (voice-to-leaderboard <3s), NFR2 (cross-device sync <5s), NFR9 (zero crashes), NFR11 (4hr offline recovery), NFR12 (Watch-to-phone delivery), NFR17 (VoiceOver labels) are **not re-verified** against post-MVP UI/sync changes. Most are unlikely to regress, but Watch implications of push notifications and Multipeer are uncovered.

### Coverage Statistics

- **PRD Phase-2/3/4 bullets covered:** 12/12 (100%)
- **PMVP-FRs total:** 18 (10 from PRD bullets + 5 launch readiness + 3 derived from UX spec)
- **PMVP-FRs with explicit story coverage:** 18/18 (100%)
- **PMVP-NFRs total:** 4
- **Stories total:** 16
- **Average stories per epic:** 2.67
- **Average acceptance criteria per story (sampled):** 4–6

### Coverage Findings

1. ✅ **All PRD post-MVP phase bullets are covered by at least one story.** No phase-roadmap requirement is orphaned.
2. ✅ **No "ghost" PMVP-FRs** — every PMVP-FR has a coverage map entry and is assigned to exactly one epic.
3. 🟡 **WARNING — Epic 9 lacks formal PRD requirement source.** Launch-readiness epic is necessary but not requirement-traced. Either (a) accept this with explicit waiver, or (b) add formal FRs to PRD before implementation.
4. 🟡 **WARNING — NFR re-verification incomplete.** 6 MVP NFRs not explicitly carried forward into post-MVP test plans. Recommend a regression-NFR appendix to the epics document.
5. 🟡 **WARNING — PMVP-NFR set is thin (4 total).** Areas with no NFR coverage:
   - Push notification delivery reliability (only "within 30 seconds" in stories, not as NFR)
   - Multipeer discovery latency target
   - Share-sheet render performance (`ImageRenderer` PNG generation time)
   - Round signature determinism stress test (volume / collision rate)
   - History card render at AX3 Dynamic Type
   - Push notification accessibility (Watch haptic patterns)
6. 🟢 **POSITIVE — UX design requirements (UX-PMVP-DR1 through DR6) bridge the design spec to stories cleanly** and are explicitly referenced in acceptance criteria.

These findings will be re-examined in Step 4 (UX Alignment) and Step 5 (Epic Quality Review).

---

## Step 4: UX Alignment

**UX Document Status:** ✅ **Found** — `ux-design-specification.md` (1573 lines, dated 2026-02).

### UX Coverage Map → PMVP-FRs

| PMVP-FR | UX Component / Journey | UX Coverage | Notes |
|---------|------------------------|-------------|-------|
| PMVP-FR1 | TestFlight build config | ❌ N/A | Engineering artifact, no UX surface |
| PMVP-FR2 | Privacy Manifest | ❌ N/A | Engineering artifact, no UX surface |
| PMVP-FR3 | Info.plist usage strings | 🟡 Indirect | UX spec §513 covers accessibility but not permission copy |
| PMVP-FR4 | App icons + launch screen | ❌ **MISSING** | No icon design or launch screen treatment in UX spec |
| PMVP-FR5 | App Store Connect record | ❌ N/A | Distribution artifact |
| PMVP-FR6 | Polished History Card | ✅ **Full** | UX spec §1126–1147 (Component #8) — anatomy, states, layout, accessibility all defined |
| PMVP-FR7 | Screenshot-First Round Summary | ✅ **Full** | UX spec §1097–1124 (Component #7) — full design spec including screenshot-first principle |
| PMVP-FR8 | Share via System Sheet | 🟡 Partial | UX spec mentions "Share button prominent" (§805, §1111) but no share-sheet flow spec, no captured-image design, no fallback for share cancellation |
| PMVP-FR9 | "Same group as last round" | ❌ **MISSING** | No UX design for Round Setup quick-add; Journey 2 (§623) covers MVP setup only |
| PMVP-FR10 | Scoring Attribution | 🟡 Partial | UX spec §995 mentions "Subtle attribution ('scored by [name]') ... fades after first few rounds" — design exists but the "fades after first few rounds" behavior conflicts with Story 10.2 which keeps attribution permanent |
| PMVP-FR11 | Push: round started | ❌ **MISSING** | No notification copy design, no deep-link landing behavior design, no Watch notification UX |
| PMVP-FR12 | Push: round complete | ❌ **MISSING** | Same as FR11 |
| PMVP-FR13 | Push: discrepancy | ❌ **MISSING** | Same as FR11; Journey 7 (§838) explicitly defers push UX to post-MVP |
| PMVP-FR14 | Score trend visualization | ❌ **MISSING** | No chart design, no empty-state design, no entry-point design |
| PMVP-FR15 | Personal best per course | ❌ **MISSING** | No UX surface design |
| PMVP-FR16 | Head-to-head record | ❌ **MISSING** | No UX surface design, no player-picker flow design |
| PMVP-FR17 | Multipeer nearby discovery | ❌ **MISSING** | No UX design for discovery indicator, no permission prompt copy, no failure state UX |
| PMVP-FR18 | Round signature | ❌ **MISSING** | Only constraint-based guidance (UX-PMVP-DR6 in epics file: "no mascots, no confetti, geometric/color-derived") — no actual visual exploration in UX spec |

### Coverage Statistics

- **PMVP-FRs with full UX coverage:** 2 / 18 (11%)
- **PMVP-FRs with partial UX coverage:** 3 / 18 (17%)
- **PMVP-FRs with no UX coverage:** 8 / 18 (44%) [excluding the 5 engineering-only FRs]
- **Of the 13 user-facing PMVP-FRs:** 2 fully covered (15%), 3 partial (23%), 8 missing (62%)

### UX ↔ PRD Alignment

| Dimension | Status |
|-----------|--------|
| MVP journeys (1–8) | ✅ Aligned with PRD journeys 1–7 + scenarios 6, 7 |
| Post-MVP journeys | ❌ **No journeys for push notifications, stats, head-to-head, nearby discovery, share-flow continuation** |
| Visual register guidance | ✅ Clear (on-course competitive vs. off-course warm) — referenced consistently in epics-post-mvp.md UX-PMVP-DR series |
| Accessibility | ✅ UX spec §1455 has comprehensive strategy applicable to all new screens |

### UX ↔ Architecture Alignment (Post-MVP)

Architecture document (`architecture.md`, 1673 lines, dated 2026-02) was authored for **MVP scope only**. Spot-check for post-MVP topics:

| Post-MVP Topic | In Architecture Doc? |
|----------------|----------------------|
| APNs entitlement / UNUserNotificationCenter | ❌ Not mentioned |
| Background Modes: Remote Notifications | 🟡 Line 230, 1243 — mentioned for CloudKit silent push, not user-facing notifications |
| MultipeerConnectivity / Bonjour | ❌ Not mentioned |
| `NSLocalNetworkUsageDescription` | ❌ Not mentioned |
| Swift Charts integration | ❌ Not mentioned |
| `ImageRenderer` for share-sheet PNG | ❌ Not mentioned |
| Privacy Manifest (`PrivacyInfo.xcprivacy`) | ❌ Not mentioned |
| Lazy notification permission flow | ❌ Not mentioned |
| `NotificationService` protocol abstraction | ❌ Not mentioned |
| `NearbyDiscoveryClient` protocol | ❌ Not mentioned |
| Architecture "Deferred Decisions (Post-MVP)" at line 303 | 🟡 Lists only "Third-party crash reporting" — does **not** capture any of the above |

**Where post-MVP architectural decisions DO live:** Only in `epics-post-mvp.md` lines 71–78 (the "Additional Requirements" section). This is a single-source-of-truth violation: the architecture document is the canonical reference (per CLAUDE.md: "read it before making significant architectural decisions") but post-MVP architecture is documented elsewhere.

### Critical UX/Architecture Findings

1. 🔴 **CRITICAL — UX spec gap for 8 of 13 user-facing post-MVP features.** Push notifications (3 PMVP-FRs), Phase 3 Memory views (3 PMVP-FRs), Multipeer discovery affordance, and round signature visuals have no UX design surface beyond constraint statements.
2. 🔴 **CRITICAL — Architecture doc not amended for post-MVP.** Five new platform integrations (APNs, Multipeer, Swift Charts, ImageRenderer, Privacy Manifest) are introduced by Epics 9–14 without corresponding architecture sections. Story-level design decisions are scattered.
3. 🟡 **WARNING — Conflict between UX spec and Story 10.2 attribution behavior.** UX spec §995 says attribution "fades after first few rounds"; Story 10.2 specifies permanent caption-tier attribution. One source must be authoritative — recommend deferring to the explicit Story 10.2 acceptance criteria and amending the UX spec note.
4. 🟡 **WARNING — Share-sheet design (PMVP-FR8) thin in UX spec.** Story 11.3 carries the implementation detail but no visual mockup of the share preview or text caption exists.
5. 🟢 **POSITIVE — UX-PMVP-DR1 through DR6 in epics file fill some gaps.** These design requirements add constraints (off-course register, geometric signature, caption-tier attribution typography, Watch haptic) that fill the missing UX-spec details for some features.
6. 🟢 **POSITIVE — Existing UX spec accessibility/Dynamic Type/contrast guidance is applicable** to all new screens without amendment.

### UX Alignment Verdict

**The UX layer is the largest readiness gap.** For a product whose PRD prioritizes "design quality registers" as a success metric (PRD line 82), shipping 8 features without UX design exploration risks an inconsistent, ad-hoc post-MVP experience.

---

## Step 5: Epic Quality Review

Applied create-epics-and-stories standards to all 6 post-MVP epics and 16 stories.

### Epic-by-Epic Quality Assessment

#### Epic 9 — TestFlight Launch Readiness

| Check | Result |
|-------|--------|
| User-value framing | 🟡 Borderline — epic goal "friend group can install hyzer-app via TestFlight" reads as user outcome, but stories are framed for the developer |
| Epic independence | ✅ No Post-MVP dependencies |
| Story 9.1 sizing | ⚠️ Pure technical milestone framed as "As the developer, I want…" — **violates user-story principle** |
| Story 9.2 sizing | 🟡 Bundles Privacy Manifest + Permission strings + App Icons (3 distinct concerns) |
| Story 9.3 sizing | 🟠 Bundles App Store Connect + TestFlight test group + unrelated `ColorTokens.border` tech debt (scope creep) |
| AC quality | ✅ Given/When/Then format used; ACs are testable |
| Forward dependencies | ✅ None |

_Resolved by Story 9.3 — Path A retained. ColorTokens.border defined and documented at HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51. The "Story 9.3 sizing" row above reflects the planning-time concern; the token-debt portion was completed within Story 9.3 rather than split. (Story 15.6, 2026-05-19)_

#### Epic 10 — Round Setup Quick-Add & Scoring Attribution

| Check | Result |
|-------|--------|
| User-value framing | ✅ Both stories deliver clear user value |
| Epic independence | ✅ Backward dep on Epic 9 only |
| Story 10.1 sizing | ✅ Single feature, well-scoped |
| Story 10.2 sizing | ✅ Single feature, well-scoped |
| AC quality | ✅ Strong — VoiceOver, AX3, supersession chain, guest player edge cases all covered |
| Bundling concern | 🟡 Two unrelated features ("quick-add" + "attribution") in one epic — defensible as "QoL wins" but could be split |

#### Epic 11 — Polished History & Shareable Round Summaries

| Check | Result |
|-------|--------|
| User-value framing | ✅ All three stories user-centric |
| Epic independence | ✅ Backward dep on Epic 9 only |
| Story progression | ✅ 11.1 → 11.2 → 11.3 builds logically |
| Story 11.3 dep | 🟡 Soft dep on 11.2 (share button on summary card) — within-epic, acceptable |
| AC quality | ✅ Brownfield callouts ("Replace the minimal X from Story Y.Y") are explicit and correct |
| Performance AC | ✅ Story 11.1 explicitly tests scroll perf at 250+ rounds (PMVP-NFR3 binding) |

#### Epic 12 — Push Notifications

| Check | Result |
|-------|--------|
| User-value framing | ✅ All three stories user-centric |
| Foundation pattern | ✅ Story 12.1 correctly bundles foundation (NotificationService protocol, APNs entitlement, lazy permission flow) with first feature |
| Within-epic deps | ✅ 12.2 and 12.3 build on 12.1's foundation — acceptable pattern |
| AC quality | ✅ Edge cases covered (self-exclusion, idempotent re-tap, no-duplicate resolution, non-organizer suppression) |
| Cross-cutting AC | ✅ PMVP-NFR1 (no PII) explicitly tested in 12.1 |
| Watch integration | ✅ Story 12.1 references UX-PMVP-DR4 for Watch haptic |
| NFR gap | 🟡 "within 30 seconds" delivery target appears in ACs but is **not a PMVP-NFR** — should be promoted to NFR for explicit performance contract |

#### Epic 13 — Long-Term Memory

| Check | Result |
|-------|--------|
| User-value framing | ✅ All three stories user-centric |
| Epic independence | ✅ Backward dep on Epic 9 + soft on Epic 11 |
| Story independence | ✅ Three features can be completed in any order |
| AC quality | ✅ Empty states, guest player handling, fetchLimit compliance (CLAUDE.md), VoiceOver chart descriptor all covered |
| Performance AC | ✅ Story 13.1 explicitly binds PMVP-NFR4 (<500ms chart render at 250 rounds) |
| Data-source assumption | 🟡 Stories assume sufficient historical data (3+ rounds for trend, multi-round for H2H). Realistic acceptance test plan should specify how to seed history. |

#### Epic 14 — Nearby Discovery & Visual Round Signature

| Check | Result |
|-------|--------|
| User-value framing | ✅ Both stories user-centric |
| Bundling concern | 🟠 **Two completely unrelated features in one epic** — Multipeer networking + generative graphics. No technical, UX, or value linkage. Recommend split into Epic 14a (Multipeer) and Epic 14b (Round Signature). |
| Epic independence | ✅ Backward dep on Epic 9 + soft on Epic 11 (signature lives on summary card) |
| Story 14.1 AC | ✅ Strong — permission denial fallback, isolation between concurrent rounds, lifecycle cleanup |
| Story 14.2 AC | ✅ Determinism explicitly tested; design system compliance (no mascots/confetti) tested |
| NFR gap | 🟡 "within 5 seconds" target in Story 14.1 not formalized as NFR |

### Cross-Cutting Quality Findings

#### 🔴 Critical Violations

1. **Story 9.1 "As the developer, I want…" framing violates user-story principle.** This is a build-configuration task and should either be reframed as a user-value story (e.g., "As a beta tester, I want a stable, signed build…") or recategorized as an engineering task outside the story system.

#### 🟠 Major Issues

2. **Epic 14 bundles unrelated features.** Multipeer discovery (networking infrastructure with significant risk surface) and generative round signature (creative visual feature) have no shared dependencies, no shared review surface, and no shared user journey. Recommend split.
3. **Story 9.3 mixes launch infrastructure with unrelated tech debt** (`ColorTokens.border`). The tech debt should be a separate story in the appropriate epic (likely Epic 11 since the polished history/summary cards would actually use the border token).
   _Resolved by Story 9.3 — Path A retained. ColorTokens.border defined and documented at HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51. The recommended split did not occur; the token-debt portion was completed within Story 9.3. (Story 15.6, 2026-05-19)_
4. **Story 9.2 bundles three concerns** (Privacy Manifest, Permission Strings, App Icons). Could be split into three smaller, cleaner stories.

#### 🟡 Minor Concerns

5. **Two implicit NFRs need formalization**: push notification delivery target (~30s) in Epic 12 stories, and Multipeer discovery latency target (~5s) in Story 14.1. These appear in ACs but should be promoted to PMVP-NFRs so the performance contract is explicit and tracked separately from feature stories.
6. **"First name" handling is unspecified.** Stories 12.1/12.2 acceptance criteria reference "[Organizer first name]" and "[Winner first name]" but `Player.displayName` is not guaranteed to be a first name (it's a user-supplied display name per FR1). No story handles the parsing/extraction. **This will block implementation.**
7. **UX-design precursor stories are absent.** For features with no UX spec coverage (PMVP-FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18), no "design the X surface" story precedes the implementation story. Implementation will require ad-hoc design decisions during development.
8. **Story 12.x: notification dispatch mechanism undefined.** ACs say "CloudKit-server-triggered notification" but CloudKit doesn't auto-dispatch APNs to users from arbitrary record saves. The implementer needs either (a) a CKSubscription-driven push (which delivers only silent notifications, not user-visible alerts), or (b) an explicit server function. Story 12.1 scope says "APNs entitlement added" and "CloudKit-server-triggered" but doesn't reconcile these. **This is an architectural gap that will block implementation.**
9. **Story 14.1 (Multipeer) data-leak ACs.** Test covers "device sees only rounds that include them as a participant" — good — but does not test the inverse: what if a malicious peer advertises a fake round? Threat model not addressed.
10. **No stories address the migration of existing in-flight rounds.** If a round is `.active` when post-MVP epics ship, do all features apply retroactively? (Quick-add reads history → yes; attribution requires `reportedByPlayerID` on existing events → already exists per Story 3.2; push notifications → only fire on new state transitions, OK.) Worth a single sentence in epic notes.

### Compliance Checklist Summary

| Best Practice | Epic 9 | Epic 10 | Epic 11 | Epic 12 | Epic 13 | Epic 14 |
|---------------|--------|---------|---------|---------|---------|---------|
| Delivers user value | 🟡 | ✅ | ✅ | ✅ | ✅ | ✅ |
| Functions independently | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Stories appropriately sized | 🟠 | ✅ | ✅ | ✅ | ✅ | 🟠 |
| No forward dependencies | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Entities created when needed | ✅ N/A | ✅ N/A | ✅ N/A | ✅ N/A | ✅ N/A | ✅ N/A |
| Clear acceptance criteria | ✅ | ✅ | ✅ | 🟡 | ✅ | ✅ |
| Traceability to FRs maintained | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**Aggregate compliance:** 36/42 boxes ✅, 5/42 🟡, 1/42 🟠.

### Story Quality Summary

- **Total stories:** 16
- **Stories with full Given/When/Then ACs:** 16/16 ✅
- **Stories with VoiceOver/accessibility coverage:** ~10/16 (62%) — some stories implicit on accessibility
- **Stories with Dynamic Type coverage:** 3/16 (19%) — only where layout could break (Story 10.2)
- **Stories with edge-case/error-state ACs:** 14/16 (88%)
- **Stories with explicit fetchLimit / coding-standards compliance:** 2/16 (13%) — Stories 13.2, 13.3 only

### Quality Verdict

Epic and story structure is generally **strong and rigorous**, with significantly higher quality than typical project documentation. The MVP epics' patterns carry through well into post-MVP. However, two structural issues (Story 9.1 framing, Epic 14 bundling) and two implementation-blocking gaps (notification dispatch mechanism, first-name parsing) must be addressed before implementation begins.

---

## Summary and Recommendations

### Overall Readiness Status

🟡 **NEEDS WORK — Not ready for implementation as-is**

**Two epics are ready to start, four are not.** The supporting planning documents (PRD, UX, Architecture) have not been amended for post-MVP scope, leaving the epics file as the de-facto source of truth for requirements, design, and architecture — which violates the BMAD layered-planning model and creates implementation risk.

**Per-epic readiness:**

| Epic | Verdict | Reason |
|------|---------|--------|
| Epic 9 (TestFlight Launch) | 🟢 **GO with minor fixes** | Story 9.1 framing + Story 9.3 scope split, otherwise unblocked |
| Epic 10 (Quick-Add + Attribution) | 🟢 **GO** | Strong scope, strong ACs, fully covered |
| Epic 11 (History + Summary) | 🟢 **GO** | Strong scope, UX coverage exists, brownfield migration explicit |
| Epic 12 (Push Notifications) | 🔴 **BLOCKED** | Notification dispatch mechanism unresolved; first-name parsing unresolved; no UX design |
| Epic 13 (Long-Term Memory) | 🟡 **GO with caveats** | Implementation-ready ACs, but no UX design for trend/bests/H2H surfaces |
| Epic 14 (Multipeer + Signature) | 🔴 **SPLIT REQUIRED** | Two unrelated features; both missing UX; Multipeer threat model absent |

### Critical Issues Requiring Immediate Action

🔴 **CRITICAL (blocks implementation):**

1. **No PRD-formal post-MVP FRs/NFRs.** The PRD's Phase 2/3/4 roadmap is narrative-only. PMVP-FR1 through PMVP-FR18 and PMVP-NFR1–4 live only in the epics document and have **not been through PRD validation**. Recommend either (a) promoting these to a `prd-post-mvp.md` companion document that runs through `bmad-validate-prd`, or (b) explicit acceptance of derived requirements with a documented waiver.

2. **Architecture document not amended for post-MVP.** Five new platform integrations (APNs, MultipeerConnectivity, Swift Charts, ImageRenderer, Privacy Manifest) are introduced by post-MVP epics without corresponding architecture sections. The `architecture.md` "Deferred Decisions (Post-MVP)" section (line 303) is stale. Recommend an `architecture-post-mvp.md` companion or amendment.

3. **UX spec not amended for post-MVP.** 8 of 13 user-facing post-MVP features have no UX design. Push notification copy and Watch haptic design, Phase 3 Memory views (trends, bests, head-to-head), Multipeer affordance, and round signature visuals are all undefined. For a product whose success criteria include "design quality registers," this is a major gap.

4. **Epic 12 has an architectural gap that will block implementation.** "CloudKit-server-triggered notification" is not a thing CloudKit does for user-visible alerts. The story scope must reconcile: CKSubscription delivers silent push; user-visible alert push requires either a server function or app-decoded silent-push notification scheduling. Decide before Story 12.1 starts.

5. **"First name" parsing is undefined.** Stories 12.1/12.2 require "first name" extraction from `Player.displayName` (which can be any user-supplied string per FR1). Either add a `Player.firstName` field, or specify the parsing rule (e.g., first whitespace-delimited token), or use full `displayName` in notification copy.

🟠 **MAJOR (significant rework if skipped):**

6. **Epic 14 should be split** into Epic 14a (Multipeer Discovery) and Epic 14b (Visual Round Signature). The two features share no technical dependencies and have very different risk profiles.

7. **Story 9.1 should be reframed** ("As the developer" violates user-value principle) or moved out of the story system entirely. Story 9.3 should drop the unrelated `ColorTokens.border` tech debt to a separate story.
   _Resolved by Story 9.3 — Path A retained. ColorTokens.border defined and documented at HyzerKit/Sources/HyzerKit/Design/ColorTokens.swift:51. The recommended drop-to-separate-story did not occur; the token-debt portion was completed within Story 9.3. (Story 15.6, 2026-05-19)_

8. **Promote two implicit performance targets to formal PMVP-NFRs:** push notification delivery latency (~30s) and Multipeer discovery latency (~5s). Without NFR status, these are scattered AC assertions instead of contract-tested performance budgets.

🟡 **MINOR (improves planning quality):**

9. Add UX-design precursor stories or a parallel UX track for the 8 design-missing features.
10. Resolve the conflict between UX spec §995 (attribution "fades after first few rounds") and Story 10.2 (permanent attribution). Recommend deferring to Story 10.2.
11. Add a Multipeer threat model section (rogue peer advertising fake rounds).
12. Add stories or sub-tasks for testing approach where the protocol abstractions (NotificationService, NearbyDiscoveryClient) need mock implementations — current Scope sections mention this but ACs don't enforce it.
13. Add accessibility ACs to stories missing them (VoiceOver labels for trend chart points, head-to-head view announcement, history card focus behavior beyond Story 11.1, share-sheet announcement).
14. Document migration behavior for in-flight rounds when post-MVP ships (probably one paragraph in the epic overview).

### Recommended Next Steps (in priority order)

1. **Decide on PRD amendment strategy.** Either run `epics-post-mvp.md` PMVP-FRs through PRD validation, or attach a written waiver. Without this, traceability is broken.
2. **Resolve Critical Issue #4 (notification dispatch mechanism)** with a 1-page architecture spike. Block Epic 12 until resolved.
3. **Resolve Critical Issue #5 (first-name parsing)** with a single-line decision in PRD/architecture (add field, parse rule, or use full displayName).
4. **Author UX design for the 8 missing features** OR explicitly accept ad-hoc design during implementation with a quality risk acknowledgment. (For a "design quality registers" success product, accepting ad-hoc design is the higher risk.)
5. **Amend architecture document** with sections for APNs, MultipeerConnectivity, Swift Charts, ImageRenderer, Privacy Manifest — or write a focused `architecture-post-mvp.md` addendum.
6. **Restructure Epic 14** (split into 14a and 14b) and fix Story 9.1, 9.3, and 9.2 structural issues.
7. **Add the two missing PMVP-NFRs** (push delivery latency, Multipeer discovery latency).
8. **Start implementation with Epics 9, 10, 11.** These are GO-ready with the minor fixes from #6. Implementation can proceed in parallel with #4 and #5 work for later epics.

### Risk Acknowledgment if Proceeding As-Is

If the user chooses to proceed without addressing the critical issues, here's the realistic risk picture:

- **Epic 12 will block within the first day of implementation.** The notification dispatch question cannot be punted to code.
- **Epics 13 and 14 will produce ad-hoc UI** with no design-system curation. The UX coherence the MVP achieved will degrade visibly.
- **Future audits will find broken traceability** — any retrospective on post-MVP can't cite "the PRD required X" because the PRD doesn't formally require any of it.
- **Two epics (10, 11) can ship cleanly** with current planning even if everything else is paused. These represent ~50% of post-MVP user-facing value and have full readiness.

### Final Note

This assessment identified **18 issues** across **5 categories** (PRD formality, UX coverage, Architecture coverage, Epic structure, Implementation-blocking gaps). The post-MVP planning artifact is **above average in rigor** but suffers from a structural mismatch: it tried to encode requirements, UX, and architecture decisions in a single epics file, when the BMAD model expects those to live in their respective planning documents.

Two epics (10 and 11) can begin implementation immediately with minor fixes. Four epics (9, 12, 13, 14) have blockers ranging from minor (Epic 9) to critical (Epic 12). Address the five Critical Issues before unblocking those four epics.

**Date:** 2026-05-13
**Assessor:** Implementation Readiness Skill (BMAD)
**Scope:** Post-MVP epics (`epics-post-mvp.md`)

