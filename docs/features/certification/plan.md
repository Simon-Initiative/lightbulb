# Implementation Plan: certification

## Phase 1: Conformance Matrix Foundations
- [ ] Create `docs/complete_lti_support/conformance_matrix.md` with agreed schema columns.
- [ ] Seed rows for all epic requirements (FR + NFR).
- [ ] Add initial mapping rows for domain cert objectives:
  - [ ] Core
  - [ ] NRPS
  - [ ] AGS
  - [ ] Deep Linking
- [ ] Add status lifecycle definitions (`not_started`, `in_progress`, `implemented`, `verified`).
- [ ] Add owner and verification-date governance rules.

## Phase 2: Matrix Validation Automation
- [ ] Add lightweight matrix lint script under `scripts/` (implementation language TBD).
- [ ] Validate required columns and status values.
- [ ] Validate every FR/NFR has at least one row.
- [ ] Validate referenced files/tests exist.
- [ ] Add script usage docs in `docs/complete_lti_support/conformance_matrix.md`.

## Phase 3: Pre-Flight Conformance Suite Structure
- [ ] Create conformance test folder structure:
  - [ ] `test/lightbulb/conformance/core_*_test.gleam`
  - [ ] `test/lightbulb/conformance/nrps_*_test.gleam`
  - [ ] `test/lightbulb/conformance/ags_*_test.gleam`
  - [ ] `test/lightbulb/conformance/deep_linking_*_test.gleam`
- [ ] Define test naming convention tied to requirement/cert objective IDs.
- [ ] Add missing negative-path tests required for certification readiness.
- [ ] Ensure conformance tests run under existing `gleam test` command.

## Phase 4: CI Quality Gates
- [ ] Update `.github/workflows/test.yml` to run matrix lint in CI.
- [ ] Fail CI when matrix lint fails.
- [ ] Fail CI when conformance tests fail.
- [ ] Keep existing format/test checks intact.

## Phase 5: Runbook Authoring
- [ ] Create `docs/complete_lti_support/certification_runbook.md`.
- [ ] Add sections:
  - [ ] environment prerequisites
  - [ ] platform registration/deployment setup
  - [ ] endpoint mapping
  - [ ] execution sequence by domain
  - [ ] failure triage
  - [ ] submission checklist
- [ ] Add date-stamped dry-run procedure template.

## Phase 6: Evidence Package Design
- [ ] Create `docs/complete_lti_support/evidence/` structure.
- [ ] Add evidence template/checklist per cert objective.
- [ ] Add `evidence/summary.md` rollup format.
- [ ] Optionally add script to generate summary index from evidence metadata.

## Phase 7: Dry Run and Verification Loop
- [ ] Execute internal dry-run following runbook.
- [ ] Capture evidence artifacts for each objective.
- [ ] Link evidence paths in conformance matrix rows.
- [ ] Move eligible rows to `verified`.
- [ ] Log open failures/remediations and rerun.

## Phase 8: Documentation and Handoff
- [ ] Update `README.md` with certification readiness pointers.
- [ ] Add maintainer instructions for keeping matrix current during feature work.
- [ ] Publish ownership model for ongoing certification upkeep.

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
- [ ] Conformance matrix exists with complete FR/NFR + cert objective coverage.
- [ ] Matrix lint automation exists and is enforced in CI.
- [ ] Conformance test suite structure exists and runs in CI.
- [ ] Certification runbook exists and is actionable.
- [ ] Evidence package structure and templates exist.
- [ ] At least one full dry-run completed and documented with linked evidence.
