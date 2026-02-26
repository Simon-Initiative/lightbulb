# Functional Design Document: certification

## 1. Normative References

- LTI 1.3 certification guide: https://www.imsglobal.org/spec/lti/v1p3/cert
- LTI Advantage overview: https://www.imsglobal.org/ltiadvantage
- Component specs used for traceability:
  - Core: https://www.imsglobal.org/spec/lti/v1p3
  - Deep Linking: https://www.imsglobal.org/spec/lti-dl/v2p0
  - AGS: https://www.imsglobal.org/spec/lti-ags/v2p0
  - NRPS: https://www.imsglobal.org/spec/lti-nrps/v2p0

## 2. Current Baseline and Gaps

Current repository state:

- Feature-level PRD/FDD/plan docs exist.
- CI (`.github/workflows/test.yml`) runs `gleam test` and formatting checks.

Current gaps for certification readiness:

- No `docs/complete_lti_support/conformance_matrix.md` artifact yet.
- No `docs/complete_lti_support/certification_runbook.md` artifact yet.
- No standardized evidence package directory or checklist.
- No explicit certification-focused test grouping and traceability metadata.
- No CI gate that validates requirement-to-test mapping completeness.

## 3. Target Artifacts and Contracts

### 3.1 Conformance Matrix Artifact

Create: `docs/complete_lti_support/conformance_matrix.md`

Required schema (table columns):

- `requirement_id` (e.g., `FR-CORE-01`, `NFR-04`)
- `spec_reference` (URL + section)
- `cert_reference` (guide section/test objective)
- `feature_slug` (`core`, `deep_linking`, `ags`, `nrps`, `oauth_provider`, `certification`)
- `implementation_refs` (file paths)
- `test_refs` (test file paths + test IDs)
- `status` (`not_started`, `in_progress`, `implemented`, `verified`)
- `owner`
- `last_verified_date`
- `evidence_refs` (paths under evidence package)

Rules:

- Every FR/NFR from epic PRD must have >= 1 row.
- Rows are immutable by ID once created; updates should modify status/refs.

### 3.2 Certification Runbook Artifact

Create: `docs/complete_lti_support/certification_runbook.md`

Required sections:

- Preconditions and environment setup
- Registration/deployment setup checklist
- Endpoint mapping checklist
- Protocol execution order (Core -> NRPS -> AGS -> Deep Linking)
- Test account/data setup requirements
- Failure triage playbook
- Submission/evidence packaging checklist

### 3.3 Evidence Package Structure

Create root: `docs/complete_lti_support/evidence/`

Proposed layout:

- `docs/complete_lti_support/evidence/README.md`
- `docs/complete_lti_support/evidence/core/`
- `docs/complete_lti_support/evidence/nrps/`
- `docs/complete_lti_support/evidence/ags/`
- `docs/complete_lti_support/evidence/deep_linking/`
- `docs/complete_lti_support/evidence/summary.md`

Per-test evidence payload:

- validator test id/objective
- execution date/time
- environment commit SHA
- request/response excerpts (redacted)
- pass/fail disposition
- notes and remediation link

## 4. Pre-Flight Conformance Test Design

### 4.1 Test Organization

Create dedicated conformance-focused test modules:

- `test/lightbulb/conformance/core_*_test.gleam`
- `test/lightbulb/conformance/nrps_*_test.gleam`
- `test/lightbulb/conformance/ags_*_test.gleam`
- `test/lightbulb/conformance/deep_linking_*_test.gleam`

Test naming convention:

- `<domain>_<cert_objective_or_requirement>_<expected_behavior>_test`

### 4.2 Coverage Requirements

- Positive-path and negative-path tests for each cert objective.
- Every conformance test linked to one matrix row.
- Fail build if matrix references missing test IDs/files.

### 4.3 CI Gating

Current CI runs `gleam test`; extend with certification governance checks:

- matrix lint check (required columns and valid statuses)
- matrix-to-test-reference existence check
- run conformance test modules as part of `gleam test`

## 5. Runtime Certification Workflow

1. Implement feature work and tests.
2. Update conformance matrix rows to `implemented` with code/test refs.
3. Run CI pre-flight suite.
4. Execute manual/validator dry-run per runbook.
5. Collect evidence artifacts and link into matrix rows.
6. Mark matrix rows `verified`.
7. Generate submission summary.

## 6. Failure and Escalation Semantics

- Missing required matrix mapping -> release blocker.
- Matrix row without test reference -> release blocker.
- Failing conformance test -> release blocker.
- Validator dry-run failures require linked remediation task before re-run.

## 7. Automation and Tooling

### 7.1 Matrix Lint Script

Add script (language/tool TBD) that validates:

- required columns present
- allowed status values only
- all requirement IDs covered
- referenced files exist

### 7.2 Evidence Index Script (Optional)

Generate `evidence/summary.md` from evidence folder metadata.

## 8. Testability Design

- Unit-level tests for matrix parser/lint script (if script is included).
- Integration-level CI test proving failure on missing matrix coverage.
- Manual verification checklist in runbook for validator execution repeatability.

## 9. File-Level Design Impact

- `docs/complete_lti_support/conformance_matrix.md` (new)
- `docs/complete_lti_support/certification_runbook.md` (new)
- `docs/complete_lti_support/evidence/` (new)
- `test/lightbulb/conformance/*` (new)
- `.github/workflows/test.yml`
- optional tooling under `scripts/` for matrix validation

## 10. Certification Traceability (Meta)

This feature is the traceability backbone for all protocol features.
Every objective in Core/NRPS/AGS/Deep Linking certification flows must map to:

- implementation path
- automated test(s)
- evidence artifact(s)
