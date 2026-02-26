# Suggested Commands

## Project Setup
```sh
xcodegen generate          # Regenerate HyzerApp.xcodeproj from project.yml (run after editing project.yml)
```

## Build
```sh
xcodebuild -project HyzerApp.xcodeproj -scheme HyzerApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Test (all — requires simulator)
```sh
xcodebuild test -project HyzerApp.xcodeproj -scheme HyzerApp \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Test (HyzerKit only — fast, no simulator)
```sh
swift test --package-path HyzerKit
```

## Lint
```sh
swiftlint lint
```

## Git
```sh
git status / git diff / git log
git checkout -b feature/<name>    # branch naming enforced by hooks
git push origin feature/<name>
gh pr create                      # create PR via GitHub CLI
```

## Useful
```sh
ls / find / grep / rg             # standard Darwin utils
cat project.yml                   # view XcodeGen config
```
