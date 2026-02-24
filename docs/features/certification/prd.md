# Product Requirements Document: certification

## 1. Problem / User Value
Certification requires explicit requirement-to-test traceability, repeatable pre-flight suites, and a runbook/evidence package for validator execution.

## 2. Scope
### In scope
- Conformance matrix artifact.
- Pre-flight suite structure and CI gating.
- Certification runbook and evidence checklist/package.

### Out of scope
- Protocol implementation work for Core/Deep Linking/AGS/NRPS itself.

## 3. Requirements in Scope
- FR-CERT-01
- NFR-04

## 4. Success Criteria
- Conformance matrix complete and mapped to code/tests.
- Pre-flight suites pass in CI.
- Validator dry-run can be executed from runbook with complete evidence output.
