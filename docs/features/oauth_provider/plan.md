# Implementation Plan: oauth_provider

## Phase 1: Token Response Tolerance and Typed Errors
- [ ] Add typed token error model (`AccessTokenError`) in `src/lightbulb/services/access_token.gleam`.
- [ ] Add tolerant token success decoder:
  - [ ] required: `access_token`, `token_type`
  - [ ] optional: `expires_in`, `scope`
- [ ] Add OAuth error decoder for non-2xx responses:
  - [ ] `error`
  - [ ] `error_description`
  - [ ] `error_uri`
- [ ] Add compatibility mapping from typed errors to existing string-return API.
- [ ] Expand tests in `test/lightbulb/services/access_token_test.gleam` for tolerant and error variants.

## Phase 2: Assertion Audience and Lifetime Hardening
- [ ] Add explicit audience source selection strategy:
  - [ ] use discovered/registered authorization server when present
  - [ ] fallback to token endpoint
- [ ] Shorten client assertion lifetime to safer default (configurable).
- [ ] Add tests for assertion claims (`iss`, `sub`, `aud`, `iat`, `exp`, `jti`, `kid`).
- [ ] Ensure errors for assertion generation failures are explicit and categorized.

## Phase 3: Provider Contract Evolution for Core Integration
- [ ] Finalize approach:
  - [ ] extend `DataProvider`, or
  - [ ] add new `LaunchContextProvider` and compose it
- [ ] Implement provider-side context persistence/retrieval semantics in memory provider.
- [ ] Add adapter constructors to preserve existing external provider integrations where possible.
- [ ] Wire updated provider usage into core launch flow in `src/lightbulb/tool.gleam`.
- [ ] Add provider migration notes for custom provider implementers.

## Phase 4: Optional Token Cache Utility
- [ ] Decide inclusion: built-in path vs opt-in helper module.
- [ ] If included, add cache types and interface:
  - [ ] key by issuer/client/scope set
  - [ ] staleness window before expiry
- [ ] Add fetch-with-cache helper that wraps `fetch_access_token`.
- [ ] Add unit tests for cache hit/miss/stale/refresh behavior.

## Phase 5: Test Matrix and Conformance Mapping
- [ ] Add/expand integration tests for:
  - [ ] token request body and headers
  - [ ] non-2xx OAuth error response mapping
  - [ ] provider context semantics required by core
- [ ] Map tests to certification-relevant rows in:
  - [ ] Core section mappings
  - [ ] AGS section mappings
  - [ ] NRPS section mappings
- [ ] Update `docs/complete_lti_support/conformance_matrix.md` with oauth/provider coverage links.

## Phase 6: Documentation and Rollout
- [ ] Update README/service docs for:
  - [ ] typed token error behavior
  - [ ] optional cache utility usage
  - [ ] provider contract changes/adapters
- [ ] Provide migration guide snippets for users with custom providers.
- [ ] Confirm backward compatibility strategy and deprecation path (if any) is documented.

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
- [ ] Token decode is tolerant and standards-aligned.
- [ ] OAuth error responses are parsed and surfaced with deterministic categories.
- [ ] Assertion audience and TTL behavior are hardened and tested.
- [ ] Provider evolution for core context semantics is implemented with migration path.
- [ ] Optional token cache decision is implemented or explicitly deferred with rationale.
- [ ] Certification mappings and docs are updated.
