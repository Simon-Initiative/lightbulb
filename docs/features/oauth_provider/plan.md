# Implementation Plan: oauth_provider

## Phase 1: Token Response Tolerance and Typed Errors
- [x] Add typed token error model (`AccessTokenError`) in `src/lightbulb/services/access_token.gleam`.
- [x] Add tolerant token success decoder:
  - [x] required: `access_token`, `token_type`
  - [x] optional: `expires_in`, `scope`
- [x] Add OAuth error decoder for non-2xx responses:
  - [x] `error`
  - [x] `error_description`
  - [x] `error_uri`
- [x] Expose typed token errors as the primary API contract.
- [x] Expand tests in `test/lightbulb/services/access_token_test.gleam` for tolerant and error variants.

## Phase 2: Assertion Audience and Lifetime Hardening
- [x] Add explicit audience source selection strategy:
  - [x] use discovered/registered authorization server when present
  - [x] fallback to token endpoint
- [x] Shorten client assertion lifetime to safer default (configurable).
- [x] Add tests for assertion claims (`iss`, `sub`, `aud`, `iat`, `exp`, `jti`, `kid`).
- [x] Ensure errors for assertion generation failures are explicit and categorized.

## Phase 3: Provider Contract Evolution for Core Integration
- [x] Finalize approach:
  - [x] extend `DataProvider`, or
  - [x] add new `LaunchContextProvider` and compose it
- [x] Implement provider-side context persistence/retrieval semantics in memory provider.
- [x] Add adapter constructors to preserve existing external provider integrations where possible.
- [x] Wire updated provider usage into core launch flow in `src/lightbulb/tool.gleam`.
- [x] Add provider migration notes for custom provider implementers.

## Phase 4: Optional Token Cache Utility
- [x] Decide inclusion: built-in path vs opt-in helper module.
- [x] If included, add cache types and interface:
  - [x] key by issuer/client/scope set
  - [x] staleness window before expiry
- [x] Add fetch-with-cache helper that wraps `fetch_access_token`.
- [x] Add unit tests for cache hit/miss/stale/refresh behavior.

## Phase 5: Test Matrix and Conformance Mapping
- [x] Add/expand integration tests for:
  - [x] token request body and headers
  - [x] non-2xx OAuth error response mapping
  - [x] provider context semantics required by core
- [x] Map tests to certification-relevant rows in:
  - [x] Core section mappings
  - [x] AGS section mappings
  - [x] NRPS section mappings
- [x] Update `docs/complete_lti_support/conformance_matrix.md` with oauth/provider coverage links.

## Phase 6: Documentation and Rollout
- [x] Update README/service docs for:
  - [x] typed token error behavior
  - [x] optional cache utility usage
  - [x] provider contract changes/adapters
- [x] Provide migration guide snippets for users with custom providers.
- [x] Document typed-only token API migration for `v2.0.0`.

## Cross-Feature Dependencies
- `core`: provider contract changes for launch context/state/nonce are consumed directly by core launch validation flow.
- `ags`: token request scope behavior must support AGS objective coverage (`5.4.x`).
- `nrps`: token request scope behavior must support NRPS objective coverage (`5.3.x`).
- `deep_linking`: key management/signing behavior should stay consistent with deep-link response JWT signing needs.
- `certification`: OAuth/provider conformance checks must be linked to matrix rows spanning core/ags/nrps.

## File-Level Execution
- `src/lightbulb/services/access_token.gleam`
- `src/lightbulb/providers/data_provider.gleam`
- `src/lightbulb/providers/memory_provider.gleam`
- `src/lightbulb/providers.gleam`
- `src/lightbulb/tool.gleam`
- `test/lightbulb/services/access_token_test.gleam`
- `test/lightbulb/providers/memory_provider/*`
- `docs/complete_lti_support/conformance_matrix.md`
- `README.md`

## Definition of Done
- [x] Token decode is tolerant and standards-aligned.
- [x] OAuth error responses are parsed and surfaced with deterministic categories.
- [x] Assertion audience and TTL behavior are hardened and tested.
- [x] Provider evolution for core context semantics is implemented with migration path.
- [x] Optional token cache decision is implemented or explicitly deferred with rationale.
- [x] Certification mappings and docs are updated.
