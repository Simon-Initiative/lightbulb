# Implementation Plan: ags

## Phase 1: Core Line Item API Completion
- [ ] Expand `LineItem` type and encoder/decoder in `src/lightbulb/services/ags/line_item.gleam` to include optional spec fields.
- [ ] Add operation-specific header helpers in `src/lightbulb/services/ags.gleam`:
  - [ ] list line items headers (`Accept: lineitemcontainer`)
  - [ ] get/create/update line item headers (`Accept: lineitem`, `Content-Type: lineitem` for writes)
- [ ] Implement new APIs in `src/lightbulb/services/ags.gleam`:
  - [ ] `get_line_item`
  - [ ] `list_line_items`
  - [ ] `update_line_item`
  - [ ] `delete_line_item`
- [ ] Implement query builder for list filters:
  - [ ] `resource_link_id`
  - [ ] `resource_id`
  - [ ] `tag`
  - [ ] `limit`
- [ ] Preserve and adapt existing helpers:
  - [ ] `create_line_item` delegates to new primitives where possible
  - [ ] `fetch_or_create_line_item` uses `list_line_items(... limit=1 ...)`

## Phase 2: Results Service Implementation
- [ ] Add `src/lightbulb/services/ags/result.gleam` with `Result` type and decoder.
- [ ] Add result container decoder in `src/lightbulb/services/ags.gleam`.
- [ ] Implement `list_results(http_provider, line_item_url, query, access_token)`.
- [ ] Support results filters:
  - [ ] `user_id`
  - [ ] `limit`
- [ ] Use derived results URL `<line_item_url>/results` preserving existing query parameters.

## Phase 3: Scope Guards and Availability Semantics
- [ ] Add scope constant `lineitem.readonly` in `src/lightbulb/services/ags.gleam`.
- [ ] Add scope helper predicates:
  - [ ] `can_read_line_items`
  - [ ] `can_write_line_items`
  - [ ] `can_post_scores`
  - [ ] `can_read_results`
- [ ] Update `grade_passback_available` semantics to align with score-posting capability.
- [ ] Ensure operation entry points fail fast with explicit `ags.scope.insufficient` errors when called against launch claims lacking required scope.

## Phase 4: Paging Support via Link Headers
- [ ] Add `src/lightbulb/http/link_header.gleam` parser for `next/prev/first/last` link relations.
- [ ] Add shared `PageLinks` and `Paged(a)` types (module placement per implementation preference).
- [ ] Update `list_line_items` and `list_results` to return paging metadata.
- [ ] Add graceful fallback behavior when link header parsing fails.

## Phase 5: Score Posting Hardening
- [ ] Update score headers to stop forcing line item container Accept header.
- [ ] Validate `post_score` success statuses include `200/201/202/204`.
- [ ] Add explicit error category mapping for invalid line item ID, request failures, and unexpected status responses.
- [ ] Verify compatibility of existing score payload model with target LMS payloads and add optionality only if needed.

## Phase 6: Test Matrix and Conformance Coverage
- [ ] Expand `test/lightbulb/services/ags_test.gleam` for:
  - [ ] line item get/list/create/update/delete request and response validation
  - [ ] results list request/response validation
  - [ ] score post status handling variants
  - [ ] query filter serialization coverage
- [ ] Add paging parser tests (new test module for `link_header` parser).
- [ ] Add scope guard tests for all operation classes.
- [ ] Add negative-path tests:
  - [ ] malformed line item payload
  - [ ] malformed result payload
  - [ ] missing/insufficient scopes
  - [ ] malformed link header
- [ ] Map all tests to AGS rows in `docs/complete_lti_support/conformance_matrix.md`.
- [ ] Add AGS certification-targeted tests aligned to LTI cert guide section 5.4:
  - [ ] `5.4.1` AGS claim availability handling
  - [ ] `5.4.2` AGS endpoint claim handling
  - [ ] `5.4.3` access token scope request behavior
  - [ ] `5.4.4` access token retrieval behavior for AGS calls
  - [ ] `5.4.5` line item create behavior
  - [ ] `5.4.6` line item retrieval behavior
  - [ ] `5.4.7` score publish behavior
  - [ ] `5.4.8` result retrieval behavior

## Phase 7: Documentation and Migration
- [ ] Update `README.md` and module docs with new AGS API surface and examples.
- [ ] Document compatibility behavior for existing functions (`create_line_item`, `fetch_or_create_line_item`, `post_score`).
- [ ] Add upgrade notes for new return types (if paged responses are additive/new functions).

## File-Level Execution
- `src/lightbulb/services/ags.gleam`
- `src/lightbulb/services/ags/line_item.gleam`
- `src/lightbulb/services/ags/result.gleam` (new)
- `src/lightbulb/http/link_header.gleam` (new)
- `test/lightbulb/services/ags_test.gleam`
- `test/lightbulb/services/ags_link_header_test.gleam` (new)
- `docs/complete_lti_support/conformance_matrix.md`
- `README.md`

## Definition of Done
- [ ] AGS line item service covers get/list/create/update/delete with documented request/response contracts.
- [ ] AGS result service implemented with required filters and tests.
- [ ] Score service behavior hardened and tested for expected status variants.
- [ ] Scope guards implemented for each operation category.
- [ ] Paging metadata is available for container responses.
- [ ] Negative-path and conformance-mapped tests are in place.
- [ ] Public docs updated with examples and migration notes.
