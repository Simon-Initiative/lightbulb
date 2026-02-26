# Implementation Plan: nrps

## Phase 1: Claim Model Correction and Public API
- [ ] Update NRPS claim type/decoder in `src/lightbulb/services/nrps.gleam`:
  - [ ] require `context_memberships_url`
  - [ ] require `service_versions`
  - [ ] ignore unknown extra fields
- [ ] Remove dependency on non-normative claim fields (`errors`, `validation_context`).
- [ ] Expose `get_nrps_claim` as public helper.
- [ ] Add claim decode unit tests for valid, invalid, and minimal payloads.

## Phase 2: Membership Model Tolerance
- [ ] Redesign `Membership` type in `src/lightbulb/services/nrps/membership.gleam` with required minimum fields (`user_id`, `roles`) and optional profile fields.
- [ ] Update membership decoder for tolerant optional-field behavior.
- [ ] Update existing tests and call sites for new type shape.
- [ ] Add explicit tests for:
  - [ ] minimal member decode
  - [ ] expanded member decode
  - [ ] missing required keys failure

## Phase 3: Options-Based Fetch API
- [ ] Add `MembershipsQuery` type (`role`, `limit`, `rlid`, optional direct `url`).
- [ ] Implement `fetch_memberships_with_options(...) -> Result(MembershipsPage, NrpsError)`.
- [ ] Keep `fetch_memberships(...)` wrapper for compatibility.
- [ ] Update request construction logic:
  - [ ] no hardcoded `limit=1000`
  - [ ] optional `role`
  - [ ] optional `limit`
  - [ ] optional `rlid`

## Phase 4: Paging and Differences Support
- [ ] Reuse/add `src/lightbulb/http/link_header.gleam` parser.
- [ ] Add NRPS page link extraction (`next`, `differences`, optional `prev/first/last`).
- [ ] Implement convenience functions:
  - [ ] `fetch_next_memberships_page(...)`
  - [ ] `fetch_differences_memberships_page(...)`
- [ ] Ensure graceful fallback when link headers are malformed.

## Phase 5: Scope and Availability Semantics
- [ ] Add/adjust scope helper `can_read_memberships(claims)`.
- [ ] Ensure `nrps_available` behavior aligns with claim + scope availability semantics.
- [ ] Add failure paths for insufficient scope with explicit typed errors (for example `ScopeInsufficient`).

## Phase 6: Test Matrix and Conformance Coverage
- [ ] Expand `test/lightbulb/services/nrps_test.gleam` with:
  - [ ] options query serialization checks
  - [ ] scope availability checks
  - [ ] tolerant member decode scenarios
- [ ] Add new paging-focused tests in `test/lightbulb/services/nrps_paging_test.gleam`:
  - [ ] next link continuation flow
  - [ ] differences link continuation flow
  - [ ] malformed link header fallback behavior
- [ ] Add certification-targeted tests aligned to NRPS section 5.3:
  - [ ] `5.3.1` claim URL handling
  - [ ] `5.3.2` scope request behavior
  - [ ] `5.3.3` access token handling for NRPS calls
  - [ ] `5.3.4` members retrieval behavior
  - [ ] `5.3.5` role-specific members retrieval behavior
- [ ] Map all NRPS tests in `docs/complete_lti_support/conformance_matrix.md`.

## Phase 7: Documentation and Migration
- [ ] Update README NRPS examples to include options API and paging usage.
- [ ] Document compatibility wrapper behavior for `fetch_memberships`.
- [ ] Add migration notes for `Membership` type shape changes.

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
- [ ] NRPS claim decode is spec-aligned and tolerant.
- [ ] Membership decode supports minimal valid payloads.
- [ ] Options-based API and compatibility wrapper both work.
- [ ] Paging/differences links are surfaced and consumable.
- [ ] Scope/availability semantics are explicit and tested.
- [ ] Certification mapping and docs are updated.
