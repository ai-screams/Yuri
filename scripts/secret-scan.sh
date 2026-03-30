#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v gitleaks >/dev/null 2>&1; then
    echo "error: Gitleaks is not installed." >&2
    echo "hint: brew install gitleaks" >&2
    exit 1
fi

gitleaks dir "$ROOT_DIR" \
    --config "$ROOT_DIR/.gitleaks.toml" \
    --report-format json \
    --report-path "$ROOT_DIR/gitleaks-report.json"
