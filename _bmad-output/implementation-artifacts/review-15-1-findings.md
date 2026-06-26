# Story 15.1 Code Review — APS Environment Production & ASC Privacy Mirror

**Reviewer:** code-reviewer subagent
**Date:** 2026-05-18
**Branch:** feature/15-1-aps-production-and-asc-privacy
**Diff:** 4 files changed, +23 / -17 lines
**Spec:** 15-1-aps-environment-production-and-app-store-connect-privacy.md
**Review mode:** full

## Summary

The committed scope is intentionally tiny: a one-line `aps-environment` flip from `development` to `production` in `HyzerApp/App/HyzerApp.entitlements`, plus story-doc/deferral-log housekeeping. The Swift surface is untouched, so CLAUDE.md concurrency/design-token/bounded-query rules are non-applicable. The edit itself is correct and the plist remains well-formed. The dev agent appropriately stopped after the automatable Tasks 1–2 and deferred Tasks 3–7 (archive, App Store Connect, CloudKit Dashboard, TestFlight regression upload) to a human with signing credentials — this is consistent with the spec's "Manual step (cannot be automated from Claude Code)" framing on Tasks 4–6. The riskiest area is operational, not codeful: flipping APS environment to `production` means any future Release archive produced from this branch (or merged into `main` and used for a TestFlight Internal build) will route APNs through `api.push.apple.com` rather than `api.development.push.apple.com`, which silently changes which device tokens are valid. Per the spec's own "Latest tech information" note this is fine for TestFlight, but it does mean the moment this merges, the `Friends Beta` group MUST get a fresh build before the next push fires (any cached dev-environment device tokens become invalid). Recommended verdict: patch-and-ship — the one substantive concern is a minor documentation drift (Task 7.4 said remove three bullets, only two were removed; the third — the Story 9.3 CloudKit Production-schema operational flag — was never actually written into `deferred-work.md` so the spec reference is itself stale).

## Findings

### [LOW] [defer] Spec Task 7.4 references a third deferral bullet that does not exist in `deferred-work.md`
- **Source:** auditor
- **Location:** `_bmad-output/implementation-artifacts/15-1-aps-environment-production-and-app-store-connect-privacy.md:64` (spec Task 7.4) vs. `_bmad-output/implementation-artifacts/deferred-work.md` (target file)
- **AC violated:** N/A — Task 7.4 references "three resolved bullets (Story 9.1 APS environment, Story 9.2 ASC Privacy mirror, Story 9.3 CloudKit schema operational flag)" but the baseline `deferred-work.md` only contains the first two. The spec citation `deferred-work.md:211` in the References block is stale — the file is 103 lines on `main`.
- **Detail:** The dev agent removed the two bullets that actually existed. The Story 9.3 "CloudKit Production schema deployment" operational flag was never written into `deferred-work.md` (likely lived only in the Story 9.3 dev notes / Open Questions). The diff is therefore consistent with the actual file state, even though it under-fulfills the literal wording of Task 7.4. No action needed on the code; the spec citation is the drift.
- **Suggested fix:** None for this branch. Optionally, in story closeout notes, document "Task 7.4: removed 2 of 3 named bullets; the Story 9.3 CloudKit schema flag was never landed in deferred-work.md and is captured in the Story 9.3 dev-notes section instead."

### [LOW] [defer] Spec Task 7.3 commit message convention not yet followed (Tasks 3–7 deferred)
- **Source:** auditor
- **Location:** commit `932023b` "chore(release): flip aps-environment to production (Story 15.1 Tasks 1-2)"
- **AC violated:** N/A (no AC requires a specific commit subject; Task 7.3 prescribes the closeout subject `chore(release): flip aps-environment to production and verify asc privacy mirror`)
- **Detail:** The current commit subject correctly scopes itself to Tasks 1–2 only, which is honest. The full Task-7.3 subject is appropriate only after Tasks 3–6 are done. Not a defect; flagging for awareness so the final merge commit can use the canonical subject.
- **Suggested fix:** When Tasks 3–7 close out (human-driven), use the canonical commit message from Task 7.3 verbatim and reference the Story 9.1 / 9.2 / 9.3 deferrals being resolved.

### [LOW] [decision_needed] Story status set to `in-progress` while Tasks 3–7 are blocked on human/manual steps
- **Source:** edge
- **Location:** `_bmad-output/implementation-artifacts/sprint-status.yaml:167`, story doc line 3
- **AC violated:** N/A
- **Detail:** The agent moved the story to `in-progress`. ACs 2, 3, 4, 5, 6 cannot be discharged from Claude Code (archive needs signing creds; ASC/CloudKit are web UI; TestFlight upload is Transporter). A future reviewer needs a clear convention: does `in-progress` block further story pickup, or is `blocked-on-human-ops` a better state? Out of scope for this review, but worth surfacing because Story 15.1 is the first operational story in Epic 15 and the precedent will get reused.
- **Suggested fix:** Decide whether to introduce a `blocked-on-human-ops` (or `partial-pending-manual`) status, or document explicitly in sprint-status.yaml that `in-progress` for operational stories means "automatable portion complete, awaiting human ops."

### [LOW] [defer] Once-merged, APS production flip invalidates cached development device tokens — needs operational guidance
- **Source:** edge
- **Location:** `HyzerApp/App/HyzerApp.entitlements:20`
- **AC violated:** N/A — AC 5 covers the upload-regression check but does not call out that the existing six `Friends Beta` testers' device tokens stored server-side (if any) from the previous `development`-APS build will no longer be valid against `api.push.apple.com`.
- **Detail:** APNs device tokens are scoped to the APS environment that issued them. Pushes to a `production`-APS build will only deliver to tokens registered by a `production`-APS build. Any backend or CloudKit-subscription state that still holds dev-env tokens will silently fail to deliver. Per Epic 12 architecture (CloudKit Server-to-Device push, not a custom backend), this is mostly handled by CloudKit re-registering on first run — but worth flagging so Task 6.3's "recommend one tester install to confirm" is explicitly framed as "confirm push delivery, not just install."
- **Suggested fix:** Augment Task 6.3 evidence with one round-started or round-complete push confirmation from the new build before closing the story.

### [LOW] [defer] No automated guard against future reversion of `aps-environment`
- **Source:** edge
- **Location:** `HyzerApp/App/HyzerApp.entitlements:19-20`
- **AC violated:** N/A
- **Detail:** A future `project.yml` regeneration, a merge resolving against an old branch, or a copy-paste from a sample project could silently revert `aps-environment` back to `development`, and there is no test or CI guard that would catch it. Story 9.1 didn't add one either; this is pre-existing.
- **Suggested fix:** Out of scope for 15.1. Could be a future tiny story: a `swift test` assertion that reads `HyzerApp/App/HyzerApp.entitlements` from disk and asserts `aps-environment = production` for Release-configuration builds (gated by an env var so dev simulator runs aren't affected). Capture as deferred.

### [LOW] [dismiss] Watch entitlements file does not exist — spec Task 1.2 / 2.2 correctly skipped
- **Source:** edge
- **Location:** `HyzerWatch/Resources/` (no `HyzerWatch.entitlements` present)
- **AC violated:** N/A
- **Detail:** Verified: `HyzerWatch/Resources/` contains only `Assets.xcassets` and `PrivacyInfo.xcprivacy`. The spec instructed "If the file has no `aps-environment` key, do NOT add one." The dev agent correctly took the no-op path. Listed for completeness.
- **Suggested fix:** None.

## Triage Counts

- decision_needed: 1
- patch: 0
- defer: 4
- dismissed: 1 (Watch entitlements no-op verified)

## Dismissed (noise log)

- Watch entitlements no-op — file does not exist in the worktree; spec correctly handled by skipping Task 2.2.

## Verdict

🟡 **Patch and ship** — no blockers in the committed code (the entitlement edit is correct and the plist remains valid). All findings are LOW severity and operational/documentary, not code defects. The two patch-worthy items (Task 7.4 spec drift on the third bullet; status-convention question on `in-progress` for partly-manual stories) are documentation concerns that can be addressed in the closeout commit when a human runs Tasks 3–7.
