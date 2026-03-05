# Implementation Plan: nrps

## Phase 1: Claim Model Correction and Public API
- [x] Update NRPS claim type/decoder in `src/lightbulb/services/nrps.gleam`:
  - [x] require `context_memberships_url`
  - [x] require `service_versions`
  - [x] ignore unknown extra fields
- [x] Remove dependency on non-normative claim fields (`errors`, `validation_context`).
- [x] Expose `get_nrps_claim` as public helper.
- [x] Add claim decode unit tests for valid, invalid, and minimal payloads.

## Phase 2: Membership Model Tolerance
- [x] Redesign `Membership` type in `src/lightbulb/services/nrps/membership.gleam` with required minimum fields (`user_id`, `roles`) and optional profile fields.
- [x] Update membership decoder for tolerant optional-field behavior.
- [x] Update existing tests and call sites for new type shape.
- [x] Add explicit tests for:
  - [x] minimal member decode
  - [x] expanded member decode
  - [x] missing required keys failure

## Phase 3: Options-Based Fetch API
- [x] Add `MembershipsQuery` type (`role`, `limit`, `rlid`, optional direct `url`).
- [x] Implement `fetch_memberships_with_options(...) -> Result(MembershipsPage, NrpsError)`.
- [x] Keep `fetch_memberships(...)` wrapper for compatibility.
- [x] Update request construction logic:
  - [x] no hardcoded `limit=1000`
  - [x] optional `role`
  - [x] optional `limit`
  - [x] optional `rlid`

## Phase 4: Paging and Differences Support
- [x] Reuse/add `src/lightbulb/http/link_header.gleam` parser.
- [x] Add NRPS page link extraction (`next`, `differences`, optional `prev/first/last`).
- [x] Implement convenience functions:
  - [x] `fetch_next_memberships_page(...)`
  - [x] `fetch_differences_memberships_page(...)`
- [x] Ensure graceful fallback when link headers are malformed.

## Phase 5: Scope and Availability Semantics
- [x] Add/adjust scope helper `can_read_memberships(claims)`.
- [x] Ensure `nrps_available` behavior aligns with claim + scope availability semantics.
- [x] Add failure paths for insufficient scope with explicit typed errors (for example `ScopeInsufficient`).

## Phase 6: Test Matrix and Conformance Coverage
- [x] Expand `test/lightbulb/services/nrps_test.gleam` with:
  - [x] options query serialization checks
  - [x] scope availability checks
  - [x] tolerant member decode scenarios
- [x] Add new paging-focused tests in `test/lightbulb/services/nrps_paging_test.gleam`:
  - [x] next link continuation flow
  - [x] differences link continuation flow
  - [x] malformed link header fallback behavior
- [x] Add certification-targeted tests aligned to NRPS section 5.3:
  - [x] `5.3.1` claim URL handling
  - [x] `5.3.2` scope request behavior
  - [x] `5.3.3` access token handling for NRPS calls
  - [x] `5.3.4` members retrieval behavior
  - [x] `5.3.5` role-specific members retrieval behavior
- [x] Map all NRPS tests in `docs/complete_lti_support/conformance_matrix.md`.

## Phase 7: Documentation and Migration
- [x] Update README NRPS examples to include options API and paging usage.
- [x] Document compatibility wrapper behavior for `fetch_memberships`.
- [x] Add migration notes for `Membership` type shape changes.

## Cross-Feature Dependencies
- `core`: NRPS claim availability depends on launch claim parsing and validated launch context.
- `oauth_provider`: NRPS access-token scope request and retrieval behavior depends on OAuth/client-assertion path.
- `ags`: shared Link-header parser should remain consistent across AGS and NRPS pagination usage.
- `certification`: NRPS objective mappings (`5.3.x`) and evidence links must be maintained in conformance artifacts.

## File-Level Execution
- `src/lightbulb/services/nrps.gleam`
- `src/lightbulb/services/nrps/membership.gleam`
- `src/lightbulb/http/link_header.gleam`
- `test/lightbulb/services/nrps_test.gleam`
- `test/lightbulb/services/nrps_paging_test.gleam` (new)
- `docs/complete_lti_support/conformance_matrix.md`
- `README.md`

## Definition of Done
- [x] NRPS claim decode is spec-aligned and tolerant.
- [x] Membership decode supports minimal valid payloads.
- [x] Options-based API and compatibility wrapper both work.
- [x] Paging/differences links are surfaced and consumable.
- [x] Scope/availability semantics are explicit and tested.
- [x] Certification mapping and docs are updated.
