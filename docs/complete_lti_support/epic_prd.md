# Epic PRD: Full LTI 1.3 + LTI Advantage Complete Support

## Document Control
- Product: Lightbulb (Gleam LTI tool library)
- Epic: Complete LTI 1.3 + Advantage support and certification readiness
- Status: Draft
- Last updated: 2026-02-21
- Related docs:
  - `docs/complete_lti_support/features/README.md`

## 1. Problem Statement
Lightbulb currently supports core portions of LTI 1.3 launch, AGS, and NRPS, but does not yet provide a full specification-compliant and certification-ready implementation of:
- LTI Core 1.3 launch validation requirements
- LTI Deep Linking 2.0
- AGS 2.0 complete service set
- NRPS 2.0 complete service set

Without full support and conformance evidence, integrators face interoperability risks across LMS platforms, and Lightbulb cannot pursue LTI Advantage Complete certification.

## 2. Vision
Make Lightbulb the most reliable Gleam-native foundation for building certified LTI 1.3 tools by delivering complete, spec-aligned APIs and certification-grade validation/test coverage.

## 3. Goals
- Deliver full Tool-side support for LTI Core 1.3, Deep Linking 2.0, AGS 2.0, and NRPS 2.0.
- Provide stable, ergonomic APIs for production integration across LMS platforms.
- Achieve readiness for LTI Advantage Complete certification with auditable evidence.
- Preserve backward compatibility where practical through additive APIs and compatibility wrappers.

## 4. Non-Goals
- Implementing platform-side LTI behavior (Lightbulb is tool-side).
- Building a hosted certification automation service.
- Guaranteeing platform-specific behavior beyond the spec and common interoperability patterns.

## 5. Success Metrics
- 100% of required items in internal conformance matrix mapped to implementation + tests.
- 0 open P0/P1 conformance gaps at certification submission readiness checkpoint.
- All pre-flight conformance suites pass in CI for Core, Deep Linking, AGS, and NRPS.
- Successful dry-run against official validator workflows with captured evidence package.

## 6. Users and Use Cases
### Primary users
- Tool developers using Lightbulb to integrate with LMS platforms.
- Platform integration engineers needing predictable interoperability and clear error surfaces.

### Core use cases
- Validate OIDC login + launch securely and spec-correctly.
- Handle both resource-link launches and deep-linking launches.
- Return deep-link content selections using signed response JWTs.
- Read class rosters via NRPS with pagination/filtering.
- Create/read/update/delete AGS line items, post scores, and read results.

## 7. Scope
### In scope
- LTI Core 1.3 validation hardening and claim typing.
- Deep Linking 2.0 request/response lifecycle support.
- AGS 2.0 complete service surface (line items, scores, results).
- NRPS 2.0 complete service surface (claim decode correctness, membership retrieval extensions).
- OAuth/provider improvements required for interoperability.
- Certification runbook, conformance matrix, and evidence workflow.

### Out of scope
- Non-LTI product features unrelated to certification path.
- UI product work beyond example/reference integration helpers.

## 8. Current Baseline and Known Gaps
### Already implemented
- OIDC login and launch validation entry points.
- Deployment validation against stored registration/deployment data.
- OAuth2 client-credentials token exchange using client assertion.
- AGS partial support (score post + basic line item helpers).
- NRPS partial support (membership fetch + service URL extraction).

### Key gaps to close
- Core:
  - only one launch message type currently handled in validation flow.
  - required claim validation coverage is incomplete.
  - `aud` handling needs robust support for string/array patterns.
  - target-link consistency with login context is not yet enforced.
  - nonce expiration semantics need stricter validation-time enforcement.
- Deep Linking:
  - no full request/response APIs for Deep Linking 2.0.
- AGS:
  - missing complete line item CRUD and results APIs.
  - scope guards and pagination handling need expansion.
- NRPS:
  - claim model and membership decoding need more spec-aligned tolerance.
  - paging/filter/differences workflows are incomplete.
- Certification:
  - negative-path conformance coverage and evidence workflow need formalization.

## 9. Requirements

## 9.1 Functional Requirements
### FR-CORE-01
Launch validation must enforce required LTI 1.3 claims and message-type-specific requirements.

### FR-CORE-02
Launch validation must support valid audience forms (`aud` string and array with `azp` handling where applicable).

### FR-CORE-03
Tool must support and distinguish `LtiResourceLinkRequest` and `LtiDeepLinkingRequest`.

### FR-DL-01
Tool must decode deep-linking settings claim and expose a typed API.

### FR-DL-02
Tool must produce valid signed `LtiDeepLinkingResponse` JWT payloads and form-post helpers.

### FR-AGS-01
Tool must support AGS line item service operations: get/list/create/update/delete.

### FR-AGS-02
Tool must support AGS score service operation: post score.

### FR-AGS-03
Tool must support AGS result service operation: list results with filter support.

### FR-AGS-04
Tool must support scope-aware operation guards for all AGS operations.

### FR-NRPS-01
Tool must decode NRPS claim structure per spec (`context_memberships_url`, `service_versions`) with tolerant handling of optional fields.

### FR-NRPS-02
Tool must retrieve memberships with support for options (role filter, limit, paging, differences workflows).

### FR-PROV-01
Provider interfaces must support required launch-state/nonce correctness semantics for secure validation.

### FR-CERT-01
Repository must include certification runbook, conformance matrix, and pre-flight conformance test suites.

## 9.2 Non-Functional Requirements
### NFR-01 Security
- Strict validation for token signature, timestamps, nonce, deployment binding, and required claim presence.
- Deterministic error mapping for invalid payload categories.

### NFR-02 Interoperability
- Tolerant decoding for optional fields and platform variation without violating required checks.

### NFR-03 Backward Compatibility
- Existing public APIs should remain functional where possible; new capabilities should be additive.

### NFR-04 Testability
- Each requirement must map to automated tests and conformance-matrix coverage.

### NFR-05 Maintainability
- New modules should separate concerns cleanly (claims, deep linking, AGS, NRPS, shared HTTP utilities).

## 10. Dependencies
- IMS specifications and certification guides:
  - https://www.imsglobal.org/spec/lti/v1p3
  - https://www.imsglobal.org/spec/lti-dl/v2p0
  - https://www.imsglobal.org/spec/lti-ags/v2p0
  - https://www.imsglobal.org/spec/lti-nrps/v2p0
  - https://www.imsglobal.org/ltiadvantage
  - https://www.imsglobal.org/spec/lti/v1p3/cert
- Existing Lightbulb provider abstractions and test framework.

## 11. Epic Deliverables by Phase

## Phase 0: Foundation + Conformance Matrix
- Deliver typed-claims direction and shared parsing utilities.
- Publish conformance matrix and architecture notes.

## Phase 1: Core 1.3 Hardening
- Cert-grade launch validation.
- aud/azp support.
- login-target consistency checks.
- stronger nonce/state semantics.

## Phase 2: Deep Linking 2.0
- Deep-link request support.
- Deep-link response JWT generation.
- content-item builders and response post helper.

## Phase 3: AGS 2.0 Complete API
- Full line item + score + result operations.
- scope checks and pagination.

## Phase 4: NRPS 2.0 Complete API
- Correct claim decoding and robust roster decoding.
- options for paging/filtering/differences/rlid workflows.

## Phase 5: OAuth + Provider Improvements
- token response tolerance and error details.
- optional token caching utility.
- provider interface updates required for correctness.

## Phase 6: Certification Package
- certification runbook.
- pre-flight suites.
- validator dry-run evidence package.

## 12. Milestones and Exit Criteria
### M1 Core Hardening Complete
- Required claim validation coverage implemented and tested.
- Core bad-payload cases (for cert readiness) covered by automated tests.

### M2 Deep Linking Complete
- Deep-link request/response workflows implemented and tested.
- Deep-link response JWT signing and required claim checks validated in tests.

### M3 AGS Complete
- Full AGS operations and pagination/scope checks implemented and tested.

### M4 NRPS Complete
- Full NRPS claim/member/paging/filter behavior implemented and tested.

### M5 Certification Ready
- Conformance matrix complete.
- Pre-flight suites green.
- Validator dry-run evidence complete.

## 13. Risks and Mitigations
- API churn risk.
  - Mitigation: additive APIs + compatibility wrappers + migration notes.
- LMS variance risk.
  - Mitigation: strict required checks + tolerant optional decode + interoperability fixtures.
- Certification negative-case failures.
  - Mitigation: codify cert bad-payload cases early and run in CI.

## 14. Resourcing and Sequencing
- Recommended order: Phase 0/1 -> Phase 2 -> Phase 3/4 (parallel possible) -> Phase 5 -> Phase 6.
- Estimated timeline:
  - Sequential: ~13 weeks
  - With AGS/NRPS overlap: ~8-10 weeks

## 15. Epic Backlog Seed (for Feature Breakdown)
The next step is to create one feature PRD + implementation plan per feature. Use this structure:
- Feature slug
- Problem / user value
- Requirements in scope
- API/design changes
- Implementation tasks (file-level)
- Test plan
- Rollout and compatibility notes
- Definition of done

Initial feature candidates:
1. `core`: claim validation, audience handling, state/target-link consistency, nonce hardening.
2. `deep_linking`: request model support, response JWT generation, content-item/form-post support.
3. `ags`: line item CRUD, results API, scope guards, paging support.
4. `nrps`: claim model correction, membership model tolerance, paging/filter/differences support.
5. `oauth_provider`: token tolerance/error mapping, provider contract evolution, optional token caching.
6. `certification`: conformance matrix, pre-flight suites, runbook and evidence package.

## 16. Open Decisions
- Whether to extend `DataProvider` directly for launch context/state persistence vs introducing a dedicated state/session provider abstraction.
- Whether token caching ships as built-in behavior or optional utility layer.
- Minimum public API stability guarantees for v1.x vs introducing a v2 compatibility boundary.

## 17. Appendix: Code Areas Impacted
- `src/lightbulb/tool.gleam`
- `src/lightbulb/services/ags.gleam`
- `src/lightbulb/services/ags/line_item.gleam`
- `src/lightbulb/services/nrps.gleam`
- `src/lightbulb/services/nrps/membership.gleam`
- `src/lightbulb/services/access_token.gleam`
- `src/lightbulb/providers/data_provider.gleam`
- `src/lightbulb/providers/memory_provider.gleam`
- New deep linking and shared HTTP/claims modules (to be added)
