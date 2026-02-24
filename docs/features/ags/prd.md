# Product Requirements Document: ags

## 1. Problem / User Value
AGS support is currently partial. Tools need complete line item, score, and result APIs plus robust scope and paging behavior.

## 2. Scope
### In scope
- Full line item service support (get/list/create/update/delete).
- Score service support (post score hardening).
- Result service support (list with filters).
- Scope guards for AGS operations.
- Paging support via Link headers.

### Out of scope
- NRPS service features.

## 3. Requirements in Scope
- FR-AGS-01
- FR-AGS-02
- FR-AGS-03
- FR-AGS-04
- NFR-02
- NFR-04
- NFR-05

## 4. Success Criteria
- Complete AGS API available and documented.
- Scope gating and paging semantics implemented.
- AGS conformance tests (positive + negative) pass.
