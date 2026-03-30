# Yuri

Yuri is a macOS menu bar window management app built with Swift and AppKit.

## Tooling

Yuri uses:

- `SwiftLint` for linting
- `SwiftFormat` for formatting
- `.editorconfig` for basic editor consistency

Install the tools with Homebrew:

```bash
brew install swiftlint swiftformat gitleaks
```

Run them from the project root:

```bash
make lint
make format
make build
make secrets
```

Xcode also runs `SwiftLint` during builds when it is installed locally. If `SwiftLint` is missing, the build shows a warning instead of failing.

## Git hooks

Install the local Git hooks once:

```bash
make install-hooks
```

The `pre-commit` hook runs:

- `SwiftFormat --lint`
- `SwiftLint --strict`

## CI

GitHub Actions runs the same lint checks and a macOS `xcodebuild` build on pushes to `main` and on pull requests.
It also runs `gitleaks` secret scanning and uploads a SARIF report to GitHub code scanning.
