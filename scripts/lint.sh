#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "error: SwiftLint is not installed." >&2
    echo "hint: brew install swiftlint" >&2
    exit 1
fi

swiftlint lint --strict --no-cache --config "$ROOT_DIR/.swiftlint.yml"
