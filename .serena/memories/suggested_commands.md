# Suggested Commands

## Project Setup
```sh
xcodegen generate          # Regenerate HyzerApp.xcodeproj from project.yml
scripts/install-hooks.sh   # Install git hooks (conventional commits, branch naming)
```

## Build
```sh
xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Test
```sh
# HyzerKit only — fast, no simulator (preferred during development)
swift test --package-path HyzerKit

# Full test suite — requires iOS Simulator
xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Lint
```sh
swiftlint lint                # Check for violations
swiftlint lint --strict       # Treat warnings as errors (CI mode)
```

## CI Helper Scripts
```sh
scripts/ci-local.sh           # Mirror full CI pipeline locally
scripts/ci-local.sh --skip-lint    # Skip SwiftLint, just run tests
scripts/ci-local.sh --kit-only     # HyzerKit tests only (fastest)
scripts/test-changed.sh       # Run tests only for changed files (git diff based)
scripts/test-changed.sh develop   # Compare against develop branch
```

## Git
```sh
git checkout -b feature/<name>    # Branch naming enforced by hooks
git commit -m 'type(scope): description'  # Conventional commits enforced
gh pr create                      # Create PR via GitHub CLI
```

## CI/CD
```sh
# GitHub Actions pipeline: .github/workflows/test.yml
# Triggers on: push/PR to main, develop
# Jobs: swiftlint → hyzerkit-tests → app-tests (sequential)
```

## Archive / TestFlight
```sh
scripts/archive-testflight.sh     # Archive and upload to TestFlight
```

## Useful Darwin Utils
```sh
xcrun simctl list devices available   # List iOS simulators
xcrun simctl boot <udid>              # Boot a simulator
```
