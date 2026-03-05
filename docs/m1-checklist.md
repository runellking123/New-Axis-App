# M1 Checklist (Foundation Hardening)

## Baseline Safety
- [x] Create dedicated M1 feature branch
- [x] Add milestone implementation plan
- [x] Add M1 checklist with acceptance criteria
- [x] Add CI workflow scaffold for pull requests

## Architecture Hardening
- [x] Add structured debug logging in core services
- [x] Remove silent notification scheduling failures
- [x] Add explicit weather service configuration/error state
- [x] Introduce dependency-injection wrappers for service access in reducers

## Data Layer Hardening
- [x] Centralize persistence save handling
- [x] Centralize persistence fetch handling
- [x] Add operation-level error context for persistence failures
- [x] Add explicit migration/versioning strategy documentation
- [x] Add data reset/export utility for QA

## Validation
- [x] Run local build verification (`xcodebuild`)
- [ ] Run CI workflow in GitHub after push
- [ ] Validate app launch + core flows smoke test

## Notes
- Remaining unchecked items roll into M1.1 if blocked by environment/tooling.
