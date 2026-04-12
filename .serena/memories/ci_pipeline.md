# CI/CD Pipeline

## GitHub Actions: `.github/workflows/test.yml`

**Triggers:** Push/PR to `main` and `develop`, with concurrency cancellation.

### Jobs (3 total, macOS-15 runners)

1. **swiftlint** (~1 min) — `swiftlint lint --strict --reporter github-actions-logging`
2. **hyzerkit-tests** (~3 min) — `swift test --package-path HyzerKit` with SPM caching
3. **app-tests** (~12 min, depends on hyzerkit-tests) — `xcodebuild test` with iOS Simulator, XcodeGen, code coverage

### Key Configuration
- Xcode version: set via `XCODE_VERSION` env var (currently `16.2`)
- SPM cache key: `${{ runner.os }}-spm-${{ hashFiles('HyzerKit/Package.resolved') }}`
- Simulator: dynamically discovered by UDID (no hardcoded device name)
- Code signing disabled for CI (`CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO`)
- Artifacts: xcresult bundles (30 day retention), failure logs (7 day retention)

### Other Workflows
- `.github/workflows/bmad-story-sync.yml` — auto-marks BMAD stories as done when GitHub issues close with merged PRs

### No Sharding / No Burn-In
- Test suite is fast (~3s for 269 HyzerKit tests) — sharding overhead exceeds benefit
- Swift Testing is deterministic — burn-in targets browser UI flakiness, not applicable here

### Local CI
```sh
scripts/ci-local.sh              # Full pipeline mirror
scripts/ci-local.sh --kit-only   # Fast: HyzerKit only
scripts/test-changed.sh          # Selective: only affected tests
```
