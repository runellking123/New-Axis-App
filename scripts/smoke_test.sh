#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[smoke] Running local build gate..."
"$ROOT_DIR/scripts/ci_local.sh"

echo "[smoke] Verifying required release artifacts..."
test -f "$ROOT_DIR/docs/implementation-plan.md"
test -f "$ROOT_DIR/docs/m4-release-checklist.md"

echo "[smoke] Smoke checks passed."
