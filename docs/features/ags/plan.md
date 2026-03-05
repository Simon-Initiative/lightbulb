# Implementation Plan: ags

## Phase 1: Core Line Item API Completion
- [x] Expand `LineItem` type and encoder/decoder in `src/lightbulb/services/ags/line_item.gleam` to include optional spec fields.
- [x] Add operation-specific header helpers in `src/lightbulb/services/ags.gleam`:
  - [x] list line items headers (`Accept: lineitemcontainer`)
  - [x] get/create/update line item headers (`Accept: lineitem`, `Content-Type: lineitem` for writes)
- [x] Implement new APIs in `src/lightbulb/services/ags.gleam`:
  - [x] `get_line_item`
  - [x] `list_line_items`
  - [x] `update_line_item`
  - [x] `delete_line_item`
- [x] Implement query builder for list filters:
  - [x] `resource_link_id`
  - [x] `resource_id`
  - [x] `tag`
  - [x] `limit`
- [x] Preserve and adapt existing helpers:
  - [x] `create_line_item` delegates to new primitives where possible
  - [x] `fetch_or_create_line_item` uses `list_line_items(... limit=1 ...)`

## Phase 2: Results Service Implementation
- [x] Add `src/lightbulb/services/ags/result.gleam` with `Result` type and decoder.
- [x] Add result container decoder in `src/lightbulb/services/ags.gleam`.
- [x] Implement `list_results(http_provider, line_item_url, query, access_token)`.
- [x] Support results filters:
  - [x] `user_id`
  - [x] `limit`
- [x] Use derived results URL `<line_item_url>/results` preserving existing query parameters.

## Phase 3: Scope Guards and Availability Semantics
- [x] Add scope constant `lineitem.readonly` in `src/lightbulb/services/ags.gleam`.
- [x] Add scope helper predicates:
  - [x] `can_read_line_items`
  - [x] `can_write_line_items`
  - [x] `can_post_scores`
  - [x] `can_read_results`
- [x] Update `grade_passback_available` semantics to align with score-posting capability.
- [x] Ensure operation entry points fail fast with explicit typed scope errors (for example `ScopeInsufficient`) when called against launch claims lacking required scope.

## Phase 4: Paging Support via Link Headers
- [x] Add `src/lightbulb/http/link_header.gleam` parser for `next/prev/first/last` link relations.
- [x] Add shared `PageLinks` and `Paged(a)` types (module placement per implementation preference).
- [x] Update `list_line_items` and `list_results` to return paging metadata.
- [x] Add graceful fallback behavior when link header parsing fails.

## Phase 5: Score Posting Hardening
- [x] Update score headers to stop forcing line item container Accept header.
- [x] Validate `post_score` success statuses include `200/201/202/204`.
- [x] Add explicit error category mapping for invalid line item ID, request failures, and unexpected status responses.
- [x] Verify compatibility of existing score payload model with target LMS payloads and add optionality only if needed.

## Phase 6: Test Matrix and Conformance Coverage
- [x] Expand `test/lightbulb/services/ags_test.gleam` for:
  - [x] line item get/list/create/update/delete request and response validation
  - [x] results list request/response validation
  - [x] score post status handling variants
  - [x] query filter serialization coverage
- [x] Add paging parser tests (new test module for `link_header` parser).
- [x] Add scope guard tests for all operation classes.
- [x] Add negative-path tests:
  - [x] malformed line item payload
  - [x] malformed result payload
  - [x] missing/insufficient scopes
  - [x] malformed link header
- [x] Map all tests to AGS rows in `docs/conformance_matrix.md`.
- [x] Add AGS certification-targeted tests aligned to LTI cert guide section 5.4:
  - [x] `5.4.1` AGS claim availability handling
  - [x] `5.4.2` AGS endpoint claim handling
  - [x] `5.4.3` access token scope request behavior
  - [x] `5.4.4` access token retrieval behavior for AGS calls
  - [x] `5.4.5` line item create behavior
  - [x] `5.4.6` line item retrieval behavior
  - [x] `5.4.7` score publish behavior
  - [x] `5.4.8` result retrieval behavior

## Phase 7: Documentation and Migration
- [x] Update `README.md` and module docs with new AGS API surface and examples.
- [x] Document compatibility behavior for existing functions (`create_line_item`, `fetch_or_create_line_item`, `post_score`).
- [x] Add upgrade notes for new return types (if paged responses are additive/new functions).

## Cross-Feature Dependencies
- `core`: AGS claim extraction and launch validation prerequisites come from core launch handling.
- `oauth_provider`: AGS scope request and token acquisition behavior depends on OAuth/client-assertion correctness.
- `nrps`: shared Link-header parsing utility should be compatible with NRPS paging/differences handling.
- `certification`: AGS objective mappings (`5.4.x`) must be maintained in conformance artifacts.

## File-Level Execution
- `src/lightbulb/services/ags.gleam`
- `src/lightbulb/services/ags/line_item.gleam`
- `src/lightbulb/services/ags/result.gleam` (new)
- `src/lightbulb/http/link_header.gleam` (new)
- `test/lightbulb/services/ags_test.gleam`
- `test/lightbulb/services/ags_link_header_test.gleam` (new)
- `docs/conformance_matrix.md`
- `README.md`

## Definition of Done
- [x] AGS line item service covers get/list/create/update/delete with documented request/response contracts.
- [x] AGS result service implemented with required filters and tests.
- [x] Score service behavior hardened and tested for expected status variants.
- [x] Scope guards implemented for each operation category.
- [x] Paging metadata is available for container responses.
- [x] Negative-path and conformance-mapped tests are in place.
- [x] Public docs updated with examples and migration notes.
