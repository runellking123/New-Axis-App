# Axis v1.0.0 Release Notes
Date: 2026-03-05

## Summary
This release completes the M1 through M4 roadmap and establishes a stable, CI-validated baseline on `main`.

## Included
- Foundation hardening across persistence, weather, notifications, and reducer dependency boundaries.
- Feature completion across Command Center, WorkSuite, FamilyHQ, SocialCircle, Explore, Balance, and Settings.
- Integration hardening for Calendar, HealthKit, and Notifications.
- Configurable intelligence/report window support (7/14/30 days).
- QA + release hardening with smoke test script and release checklist.
- Accessibility improvements on primary navigation and command actions.

## Validation
- Local build gate passes.
- Smoke script passes: `scripts/smoke_test.sh`.
- GitHub iOS CI passes on `main`.

## Key References
- `docs/implementation-plan.md`
- `docs/m1-checklist.md`
- `docs/m4-release-checklist.md`
- `docs/m1-m4-release-summary.md`
