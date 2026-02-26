# Task Completion Checklist

When finishing any coding task:

1. **Lint:** `swiftlint lint` — fix any errors before committing.
2. **Tests:** `swift test --package-path HyzerKit` for domain changes; full `xcodebuild test` for ViewModel/UI changes.
3. **Branch:** Must be on `feature/<name>`, `hotfix/<name>`, or `release/v<x.y.z>` — not `main`/`develop`.
4. **Commit:** Conventional Commits format — `type(scope): description`.
5. **PR:** `gh pr create` — direct push to main is blocked by hook.

## Key Files to Update When Adding Features
- New SwiftData model → add to domain store in `HyzerApp/App/HyzerApp.swift` (ModelContainer schema)
- New service → define protocol in HyzerKit, implement in HyzerApp, wire in `AppServices.swift`
- New screen → View in `HyzerApp/Views/`, ViewModel in `HyzerApp/ViewModels/`
- New design token → add to appropriate file in `HyzerKit/Sources/HyzerKit/Design/`

## Architecture Docs
- Full architecture decisions: `_bmad-output/planning-artifacts/architecture.md`
- Sprint status: `_bmad-output/implementation-artifacts/sprint-status.yaml`
- Story files: `_bmad-output/implementation-artifacts/<story-id>-*.md`
