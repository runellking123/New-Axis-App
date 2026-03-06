# Axis M1-M4 Release Summary

## Scope Completed
- M1 Foundation Hardening
- M2 Feature Completion
- M3 Integrations + Intelligence
- M4 QA + Release Hardening

## M1 Highlights
- Added implementation and migration docs.
- Added local CI script and GitHub iOS CI workflow.
- Hardened core services (persistence, weather config fallback/error paths, notifications logging).
- Introduced dependency clients in reducers for cleaner architecture boundaries.

## M2 Highlights
- WorkSuite: focus timer pause/resume, history, sorting modes.
- Settings: persisted and enforced focus duration, steps goals, notification/haptic toggles.
- Command Center: profile-based personalization.
- SocialCircle: call/message actions with normalized phone handling.
- Explore/Family/Balance: practical UX completion (directions, event filters, report controls).

## M3 Highlights
- Calendar integration now refreshes auth state and safely clears stale data if unauthorized.
- Notifications integration now schedules/cancels Day Brief from Settings consistently.
- Weekly report now supports configurable time windows (7/14/30 days).

## M4 Highlights
- Added release checklist: `docs/m4-release-checklist.md`.
- Added smoke regression script: `scripts/smoke_test.sh`.
- Added accessibility labels/hints for primary navigation and command actions.
- Verified local smoke/build + GitHub CI pass.

## Validation Status
- Local build gate: pass.
- Smoke script: pass.
- GitHub iOS CI on milestone branch: pass.
