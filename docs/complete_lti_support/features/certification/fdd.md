# Functional Design Document: certification

## 1. Functional Scope
- Maintain requirement-to-test mapping artifact.
- Organize and gate conformance pre-flight suites.
- Provide deterministic certification execution documentation and evidence format.

## 2. Functional Architecture
### Public API
- None (docs/test governance feature).

### Internal Design
- Conformance matrix schema with requirement ID, code area, tests, status, owner.
- Test suite organization by domain: Core, Deep Linking, AGS, NRPS.
- Runbook sections for setup, execution, validation, and evidence capture.

## 3. Runtime Flow
1. Update conformance matrix for implemented features.
2. Execute pre-flight suite in CI.
3. Execute validator dry-run per runbook.
4. Capture and store evidence package.

## 4. Error Semantics
- Missing mappings/tests are treated as release blockers for certification readiness.

## 5. Testability Design
- CI enforces pre-flight suite pass condition.
- Runbook includes verification checkpoints and failure triage steps.
