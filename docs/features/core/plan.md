# Implementation Plan: core

## Phase 1: Validation Baseline and Claim Matrix
- [x] Add a core validation matrix in code comments/docs mapping each required claim to validator function.
- [x] Implement explicit required claim checks for `LtiResourceLinkRequest`:
  - [x] message type claim
  - [x] LTI version claim (`1.3.0`)
  - [x] deployment_id
  - [x] target_link_uri claim
  - [x] resource_link.id
  - [x] roles list
- [x] Normalize typed error variants for claim failures (`JwtInvalidClaim`, `MessageTypeUnsupported`, etc.).

## Phase 2: Audience and Registration Resolution
- [x] Replace `aud` string-only decode path with `aud` string-or-list support.
- [x] Implement deterministic `aud`/`azp` algorithm for client_id resolution.
- [x] Validate resolved client_id is part of token audience context.
- [x] Preserve registration lookup behavior through `(issuer, client_id)` provider call.
- [x] Add audience matrix tests:
  - [x] single-aud success
  - [x] multi-aud with azp success
  - [x] multi-aud without azp failure
  - [x] azp not in aud failure

## Phase 3: State Context and Target Link Consistency
- [x] Finalize provider extension strategy:
  - [x] extend `DataProvider` directly, or
  - [x] add dedicated state context provider and adapter
- [x] Implement login-context persistence at OIDC login:
  - [x] state
  - [x] target_link_uri
  - [x] issuer
  - [x] client_id
  - [x] expiration timestamp
- [x] Implement login-context retrieval/consume at launch validation.
- [x] Enforce launch `target_link_uri` claim equality with stored login context.
- [x] Add state/context tests:
  - [x] missing context
  - [x] expired context
  - [x] mismatched target_link_uri

## Phase 4: Nonce Hardening and Time Validation
- [x] Update memory provider nonce validation to enforce expiration during validation, not only via cleanup.
- [x] Preserve nonce one-time-use semantics for replay prevention.
- [x] Add explicit nonce error mapping for not-found vs expired vs replay.
- [x] Review timestamp skew behavior and make skew configurable or increase default tolerance.
- [x] Add boundary tests for `exp`, `iat` (and `nbf` if added).

## Phase 5: JWT/JWKS and HTTP Robustness
- [x] Normalize JWKS fetch `Accept` header to standard JSON expectations.
- [x] Harden JWK selection and decode error messages (missing `kid`, malformed keyset).
- [x] Add tests for unknown `kid` and malformed keyset payload behavior.

## Phase 6: Core Test Suite Build-Out
- [x] Add new `test/lightbulb/core_test.gleam` with end-to-end launch validation tests.
- [x] Add fixtures/utilities for signed JWT generation covering success and failure classes.
- [x] Add test scenarios:
  - [x] successful resource-link launch
  - [x] missing required claim failures
  - [x] invalid version failure
  - [x] unsupported message type failure
  - [x] audience and azp failures
  - [x] deployment mismatch failure
  - [x] state mismatch failure
  - [x] target_link_uri mismatch failure
  - [x] expired/replayed nonce failures
  - [x] invalid signature / unknown kid failure

## Phase 7: Certification Traceability and Docs
- [x] Map core test scenarios to Core tool-test objectives in the LTI certification guide.
- [x] Update `docs/conformance_matrix.md` with core mapping rows.
- [x] Update `README.md` launch flow docs for any provider/API additions.
- [x] Add migration notes for provider implementers if interfaces changed.

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
- `docs/conformance_matrix.md`
- `README.md`

## Definition of Done
- [x] Core required claims validated for resource-link launch.
- [x] Audience/azp parsing and registration resolution are fully covered by tests.
- [x] State context + target-link consistency enforcement implemented.
- [x] Nonce and timestamp hardening implemented with boundary coverage.
- [x] Core end-to-end test suite exists and passes.
- [x] Certification mapping for core is documented.
- [x] Backward compatibility/migration notes are documented.
