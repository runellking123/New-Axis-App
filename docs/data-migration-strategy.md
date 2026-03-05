# Data Migration Strategy (SwiftData)

## Scope
This document defines how Axis should evolve SwiftData models without breaking existing local user data.

## Rules
- Prefer additive changes first (new optional properties with safe defaults).
- Avoid renaming/removing model properties without a migration release.
- Never ship destructive schema changes and feature changes in the same release.

## Versioning Process
1. Introduce model changes behind compatibility defaults.
2. Add migration notes to release PR:
   - models touched
   - old -> new field map
   - fallback/default behavior
3. Run local upgrade test on existing simulator data.
4. Validate app launch and CRUD on each major module.

## Safety Checklist Before Release
- App launches on existing data without crash.
- Existing records still visible in each module.
- New fields are populated or gracefully empty.
- Reset utility (`PersistenceService.resetAllData()`) verified in debug build.

## Rollback Guidance
- Keep prior release build available.
- If migration causes startup failure, hotfix by:
  - restoring backward-compatible schema,
  - preserving fields as optional,
  - avoiding immediate destructive deletes.

## Current Gaps
- No automated migration tests yet.
- No export/import backup flow yet (planned M1.1/M2).
