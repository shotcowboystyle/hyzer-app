# Hardware Verification Test Plan — HyzerApp v1.0

TestFlight build validation checklist. Every item must pass on real hardware before App Store submission.

**Test Devices:** iPhone (iOS 18+), Apple Watch (watchOS 11+)
**Tester Count Target:** 3–5 internal testers minimum

---

## Pre-Flight Checks

- [ ] App installs from TestFlight without crash
- [ ] Watch app auto-installs on paired Apple Watch
- [ ] App launches to expected first-run state (no stale data)
- [ ] iCloud account is signed in on device
- [ ] CloudKit container `iCloud.com.shotcowboystyle.hyzerapp` is accessible

---

## Epic 1: Project Foundation & First Launch

### 1.1 First Launch Experience
- [ ] App launches with dark theme (`#0A0A0C` background)
- [ ] All text is legible at default Dynamic Type size
- [ ] Navigation between tabs works without lag

### 1.2 Player Management
- [ ] Can create a new player profile
- [ ] Player data persists after force-quit and relaunch
- [ ] SwiftData domain store is functional on device

### 1.3 Design System Verification
- [ ] Colors match dark-first palette (no white/light backgrounds leaking)
- [ ] Typography scales correctly at all Dynamic Type sizes (test at Default, AX1, AX3)
- [ ] Spacing and touch targets feel correct on physical screen (44pt minimum)

---

## Epic 2: Course Management

### 2.1 Course Creation
- [ ] Can create a course with 9 or 18 holes
- [ ] Par values save correctly for each hole
- [ ] Course persists after app restart

### 2.2 Course Selection
- [ ] Course list loads and displays correctly
- [ ] Can select a course to start a round
- [ ] Search/filter works if implemented

---

## Epic 3: Round Scoring & Live Leaderboard

### 3.1 Start Round
- [ ] Can start a new round with selected course and players
- [ ] Round initializes with correct hole count and pars

### 3.2 Score Entry (Manual)
- [ ] Can enter strokes for each player on each hole
- [ ] Score colors display correctly (eagle, birdie, par, bogey, double+)
- [ ] Touch targets are large enough for outdoor use (52pt scoring targets)

### 3.3 Score Navigation
- [ ] Can navigate between holes (forward/back)
- [ ] Score state is preserved when navigating between holes
- [ ] Current hole indicator is visible

### 3.4 Live Leaderboard
- [ ] Leaderboard updates in real-time as scores are entered
- [ ] Standings order is correct (lowest relative-to-par first)
- [ ] Leaderboard pill animation is smooth (no jank)

### 3.5 Complete Round
- [ ] Can complete/finalize a round
- [ ] Round status transitions correctly (active → completed)
- [ ] Final scores are accurate

### 3.6 Score Correction
- [ ] Can correct a previously entered score
- [ ] Correction creates new ScoreEvent (event sourcing — verify via leaderboard update)
- [ ] Leaderboard reflects corrected score immediately

---

## Epic 4: Cross-Device Sync (CloudKit)

### 4.1 Push to CloudKit
- [ ] Score events sync to CloudKit (verify in CloudKit Dashboard)
- [ ] No duplicate records appear in CloudKit
- [ ] Sync status indicator reflects actual state (syncing → idle)

### 4.2 Pull from CloudKit
- [ ] Events created on another device appear after pull
- [ ] Leaderboard updates after remote data arrives
- [ ] No data loss during sync cycle

### 4.3 Offline → Online Recovery
- [ ] **CRITICAL:** Enable Airplane Mode, enter scores for 3+ holes
- [ ] Disable Airplane Mode — verify all offline scores sync to CloudKit
- [ ] No data loss, no duplicates after reconnection
- [ ] Extended offline: play 9+ holes offline, verify full sync on reconnect

---

## Epic 5: Voice Scoring

### 5.1 Voice Recognition — Basic
- [ ] Microphone permission prompt appears on first use
- [ ] Speech recognition permission prompt appears on first use
- [ ] Can speak a score and see it recognized (e.g., "three")
- [ ] Recognition works in quiet environment
- [ ] Recognition works with moderate background noise (outdoor course simulation)

### 5.2 Voice with Player Names
- [ ] Can speak "Player Name three" and score is attributed correctly
- [ ] Fuzzy name matching works for partial/mispronounced names (Levenshtein)
- [ ] VoiceOver users can interact with voice overlay without conflict

### 5.3 Voice Auto-Commit
- [ ] Auto-commit timer fires after voice score entry
- [ ] Timer pauses when VoiceOver is active
- [ ] User can cancel before auto-commit
- [ ] Visual countdown is clear and visible outdoors

---

## Epic 6: Score Discrepancy Resolution

### 6.1 Conflict Detection & Resolution
- [ ] When Phone and Watch have different scores for same hole, discrepancy is detected
- [ ] Resolution UI presents both values clearly
- [ ] User can choose the correct value
- [ ] Resolution creates new authoritative ScoreEvent
- [ ] VoiceOver can navigate the resolution UI fully

---

## Epic 7: Apple Watch Companion

### 7.1 Watch App Launch
- [ ] Watch app launches and shows current round (if active)
- [ ] Watch displays leaderboard standings
- [ ] Watch UI is legible on small screen

### 7.2 Watch Score Entry
- [ ] **Crown entry:** Can enter score using Digital Crown
- [ ] **Voice entry via Phone mic relay:** Can trigger voice from Watch, processing happens on Phone
- [ ] Watch sends score events to Phone via WatchConnectivity
- [ ] Score appears on Phone leaderboard after Watch entry

### 7.3 Watch ↔ Phone Connectivity
- [ ] **CRITICAL:** Watch receives leaderboard updates from Phone in real-time
- [ ] Haptic feedback fires on Watch when standings change
- [ ] Haptics do NOT fire when standings are unchanged (no phantom haptics)
- [ ] WatchConnectivity recovers after temporary disconnection (walk away from phone, return)
- [ ] Session activation/deactivation is handled gracefully

---

## Epic 8: Round History & Memory

### 8.1 History List
- [ ] Completed rounds appear in history
- [ ] History shows round date, course, and final scores
- [ ] History persists across app restarts

### 8.2 Player Hole-by-Hole Breakdown
- [ ] Can view detailed hole-by-hole scores for any player in a completed round
- [ ] Score colors are consistent with live scoring view
- [ ] Share functionality works (if implemented)

---

## Cross-Cutting Concerns

### Accessibility
- [ ] **VoiceOver full pass:** Navigate every screen with VoiceOver enabled
  - [ ] All buttons have `.accessibilityLabel`
  - [ ] Score entry is fully operable with VoiceOver
  - [ ] Leaderboard announces standings correctly
  - [ ] Voice overlay is VoiceOver-compatible
  - [ ] Watch app works with VoiceOver
- [ ] **Dynamic Type:** Set to AX3 (largest), verify no truncation or overlap
- [ ] **Reduce Motion:** Enable Reduce Motion, verify animations are disabled/simplified
- [ ] **Bold Text:** Enable Bold Text, verify text remains legible

### Performance
- [ ] App launch time < 2 seconds (cold start)
- [ ] Score entry responds within 100ms (no perceptible lag)
- [ ] Leaderboard updates feel instant
- [ ] No memory warnings during a full 18-hole round
- [ ] Battery impact is reasonable during active round (< 5% per 18 holes)

### Reliability
- [ ] Force-quit during active round → relaunch → round state is preserved
- [ ] Low battery during sync → no data corruption
- [ ] Backgrounding app during sync → sync completes when foregrounded
- [ ] Notification permission prompt appears correctly (for CloudKit push)

### Edge Cases
- [ ] Start round with 1 player (solo round)
- [ ] Start round with max players (4+ if supported)
- [ ] Very long player names (20+ characters) — no truncation in critical UI
- [ ] Rapid score entry (enter all 18 holes quickly) — no data loss
- [ ] Switch between Phone and Watch score entry mid-round

---

## Sign-Off

| Area | Tester | Date | Pass/Fail | Notes |
|------|--------|------|-----------|-------|
| Epic 1: Foundation | | | | |
| Epic 2: Courses | | | | |
| Epic 3: Scoring | | | | |
| Epic 4: Sync | | | | |
| Epic 5: Voice | | | | |
| Epic 6: Discrepancy | | | | |
| Epic 7: Watch | | | | |
| Epic 8: History | | | | |
| Accessibility | | | | |
| Performance | | | | |
| Edge Cases | | | | |

**TestFlight Build Version:** ___
**Test Date Range:** ___
**Overall Verdict:** PASS / FAIL / CONDITIONAL PASS
