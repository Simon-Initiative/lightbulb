# Implementation Plan: core

## Phase 1: Validation Baseline and Claim Matrix
- [ ] Add a core validation matrix in code comments/docs mapping each required claim to validator function.
- [ ] Implement explicit required claim checks for `LtiResourceLinkRequest`:
  - [ ] message type claim
  - [ ] LTI version claim (`1.3.0`)
  - [ ] deployment_id
  - [ ] target_link_uri claim
  - [ ] resource_link.id
  - [ ] roles list
- [ ] Normalize error categories for claim failures (`core.jwt.invalid_claim`, `core.message_type.unsupported`, etc.).

## Phase 2: Audience and Registration Resolution
- [ ] Replace `aud` string-only decode path with `aud` string-or-list support.
- [ ] Implement deterministic `aud`/`azp` algorithm for client_id resolution.
- [ ] Validate resolved client_id is part of token audience context.
- [ ] Preserve registration lookup behavior through `(issuer, client_id)` provider call.
- [ ] Add audience matrix tests:
  - [ ] single-aud success
  - [ ] multi-aud with azp success
  - [ ] multi-aud without azp failure
  - [ ] azp not in aud failure

## Phase 3: State Context and Target Link Consistency
- [ ] Finalize provider extension strategy:
  - [ ] extend `DataProvider` directly, or
  - [ ] add dedicated state context provider and adapter
- [ ] Implement login-context persistence at OIDC login:
  - [ ] state
  - [ ] target_link_uri
  - [ ] issuer
  - [ ] client_id
  - [ ] expiration timestamp
- [ ] Implement login-context retrieval/consume at launch validation.
- [ ] Enforce launch `target_link_uri` claim equality with stored login context.
- [ ] Add state/context tests:
  - [ ] missing context
  - [ ] expired context
  - [ ] mismatched target_link_uri

## Phase 4: Nonce Hardening and Time Validation
- [ ] Update memory provider nonce validation to enforce expiration during validation, not only via cleanup.
- [ ] Preserve nonce one-time-use semantics for replay prevention.
- [ ] Add explicit nonce error mapping for not-found vs expired vs replay.
- [ ] Review timestamp skew behavior and make skew configurable or increase default tolerance.
- [ ] Add boundary tests for `exp`, `iat` (and `nbf` if added).

## Phase 5: JWT/JWKS and HTTP Robustness
- [ ] Normalize JWKS fetch `Accept` header to standard JSON expectations.
- [ ] Harden JWK selection and decode error messages (missing `kid`, malformed keyset).
- [ ] Add tests for unknown `kid` and malformed keyset payload behavior.

## Phase 6: Core Test Suite Build-Out
- [ ] Add new `test/lightbulb/core_test.gleam` with end-to-end launch validation tests.
- [ ] Add fixtures/utilities for signed JWT generation covering success and failure classes.
- [ ] Add test scenarios:
  - [ ] successful resource-link launch
  - [ ] missing required claim failures
  - [ ] invalid version failure
  - [ ] unsupported message type failure
  - [ ] audience and azp failures
  - [ ] deployment mismatch failure
  - [ ] state mismatch failure
  - [ ] target_link_uri mismatch failure
  - [ ] expired/replayed nonce failures
  - [ ] invalid signature / unknown kid failure

## Phase 7: Certification Traceability and Docs
- [ ] Map core test scenarios to Core tool-test objectives in the LTI certification guide.
- [ ] Update `docs/complete_lti_support/conformance_matrix.md` with core mapping rows.
- [ ] Update `README.md` launch flow docs for any provider/API additions.
- [ ] Add migration notes for provider implementers if interfaces changed.

## Cross-Feature Dependencies
- `oauth_provider`: provider contract evolution for login context/state persistence and nonce semantics (Phase 3/4 alignment).
- `deep_linking`: shared message-type routing in `src/lightbulb/tool.gleam`; core must expose deterministic unsupported/supported message handling.
- `certification`: core conformance tests and matrix mappings are required before certification-ready status.

## File-Level Execution
- `src/lightbulb/tool.gleam`
- `src/lightbulb/providers/data_provider.gleam`
- `src/lightbulb/providers/memory_provider.gleam`
- `src/lightbulb/nonce.gleam` (optional)
- `test/lightbulb/core_test.gleam` (new)
- `test/lightbulb/providers/memory_provider/tables_test.gleam` (if provider persistence logic expands)
- `docs/complete_lti_support/conformance_matrix.md`
- `README.md`

## Definition of Done
- [ ] Core required claims validated for resource-link launch.
- [ ] Audience/azp parsing and registration resolution are fully covered by tests.
- [ ] State context + target-link consistency enforcement implemented.
- [ ] Nonce and timestamp hardening implemented with boundary coverage.
- [ ] Core end-to-end test suite exists and passes.
- [ ] Certification mapping for core is documented.
- [ ] Backward compatibility/migration notes are documented.
