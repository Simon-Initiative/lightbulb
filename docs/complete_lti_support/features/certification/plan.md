# Implementation Plan: certification

## Phase 1: Conformance Matrix
- [ ] Define matrix schema.
- [ ] Map all FR/NFR items to modules and tests.
- [ ] Add ownership/status fields and update cadence.

## Phase 2: Pre-Flight Suites
- [ ] Group and normalize tests into Core/Deep Linking/AGS/NRPS domains.
- [ ] Fill gaps for required and bad-payload scenarios.
- [ ] Add CI gating for suite pass/fail.

## Phase 3: Runbook and Evidence
- [ ] Author certification runbook with environment and execution steps.
- [ ] Define evidence checklist and artifact structure.
- [ ] Execute dry-run and refine instructions.

## File-Level Execution
- `docs/complete_lti_support/conformance_matrix.md`
- `docs/complete_lti_support/certification_runbook.md`
- `test/lightbulb/...`
- CI config files
