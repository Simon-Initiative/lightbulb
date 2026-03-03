# Implementation Plan: certification

## Phase 1: Conformance Matrix Foundations
- [x] Create `docs/complete_lti_support/conformance_matrix.md` with agreed schema columns.
- [x] Seed rows for all epic requirements (FR + NFR).
- [x] Add initial mapping rows for domain cert objectives:
  - [x] Core
  - [x] NRPS
  - [x] AGS
  - [x] Deep Linking
- [x] Add status lifecycle definitions (`not_started`, `in_progress`, `implemented`, `verified`).
- [x] Add owner and verification-date governance rules.

## Phase 2: Matrix Validation Automation
- [x] Add lightweight matrix lint script under `scripts/` (implementation language TBD).
- [x] Validate required columns and status values.
- [x] Validate every FR/NFR has at least one row.
- [x] Validate referenced files/tests exist.
- [x] Add script usage docs in `docs/complete_lti_support/conformance_matrix.md`.

## Phase 3: Pre-Flight Conformance Suite Structure
- [x] Create conformance test folder structure:
  - [x] `test/lightbulb/conformance/core_*_test.gleam`
  - [x] `test/lightbulb/conformance/nrps_*_test.gleam`
  - [x] `test/lightbulb/conformance/ags_*_test.gleam`
  - [x] `test/lightbulb/conformance/deep_linking_*_test.gleam`
- [x] Define test naming convention tied to requirement/cert objective IDs.
- [x] Add missing negative-path tests required for certification readiness.
- [x] Ensure conformance tests run under existing `gleam test` command.

## Phase 4: CI Quality Gates
- [x] Update `.github/workflows/test.yml` to run matrix lint in CI.
- [x] Fail CI when matrix lint fails.
- [x] Fail CI when conformance tests fail.
- [x] Keep existing format/test checks intact.

## Phase 5: Runbook Authoring
- [x] Create `docs/complete_lti_support/certification_runbook.md`.
- [x] Add sections:
  - [x] environment prerequisites
  - [x] platform registration/deployment setup
  - [x] endpoint mapping
  - [x] execution sequence by domain
  - [x] failure triage
  - [x] submission checklist
- [x] Add date-stamped dry-run procedure template.

## Phase 6: Evidence Package Design
- [x] Create `docs/complete_lti_support/evidence/` structure.
- [x] Add evidence template/checklist per cert objective.
- [x] Add `evidence/summary.md` rollup format.
- [x] Optionally add script to generate summary index from evidence metadata.

## Phase 7: Dry Run and Verification Loop
- [x] Execute internal dry-run following runbook.
- [x] Capture evidence artifacts for each objective.
- [x] Link evidence paths in conformance matrix rows.
- [x] Move eligible rows to `verified`.
- [x] Log open failures/remediations and rerun.

## Phase 8: Documentation and Handoff
- [x] Update `README.md` with certification readiness pointers.
- [x] Add maintainer instructions for keeping matrix current during feature work.
- [x] Publish ownership model for ongoing certification upkeep.

## Cross-Feature Dependencies
- `core`: provides launch/security conformance objectives and evidence inputs.
- `deep_linking`: provides deep-link objective mappings (`6.2.x`) and response-evidence artifacts.
- `ags`: provides AGS objective mappings (`5.4.x`) and service-interaction evidence.
- `nrps`: provides NRPS objective mappings (`5.3.x`) and roster-evidence artifacts.
- `oauth_provider`: provides token/provider correctness evidence that underpins core/ags/nrps objectives.

## File-Level Execution
- `docs/complete_lti_support/conformance_matrix.md` (new)
- `docs/complete_lti_support/certification_runbook.md` (new)
- `docs/complete_lti_support/evidence/` (new)
- `test/lightbulb/conformance/*` (new)
- `.github/workflows/test.yml`
- `scripts/*` (new, optional)
- `README.md`

## Definition of Done
- [x] Conformance matrix exists with complete FR/NFR + cert objective coverage.
- [x] Matrix lint automation exists and is enforced in CI.
- [x] Conformance test suite structure exists and runs in CI.
- [x] Certification runbook exists and is actionable.
- [x] Evidence package structure and templates exist.
- [x] At least one full dry-run completed and documented with linked evidence.
