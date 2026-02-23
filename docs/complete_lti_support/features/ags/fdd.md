# Functional Design Document: ags

## 1. Normative References
- AGS 2.0 spec: https://www.imsglobal.org/spec/lti-ags/v2p0/
- LTI 1.3 certification guide (AGS tool tests section): https://www.imsglobal.org/spec/lti/v1p3/cert

Key normative points used in this design:
- Scopes and allowed methods are defined in AGS section 3.1.
- Line item list filters include `resource_link_id`, `resource_id`, `tag`, and `limit`.
- Results service is derived from line item URL as `lineitem_url/results` and supports `user_id` narrowing.
- Paging uses HTTP `Link` headers for containers.

## 2. Current Baseline and Gaps
Current code (`src/lightbulb/services/ags.gleam`) implements:
- `post_score`
- `create_line_item`
- `fetch_or_create_line_item`
- AGS claim decode and one availability helper

Gaps vs AGS 2.0:
- Missing line item `get/list/update/delete` operations.
- Missing results service (`GET lineitem_url/results`) APIs.
- Missing scope constant: `https://purl.imsglobal.org/spec/lti-ags/scope/lineitem.readonly`.
- `grade_passback_available` currently checks only `result.readonly`, which is not the right permission check for score posting.
- Line item model is too narrow for full interoperability.
- No paging support for container responses.
- Header/media-type handling is currently oversimplified (same Accept for all line item operations).

## 3. Target Public API

### 3.1 Constants
- Keep existing:
  - `lineitem_scope_url`
  - `result_readonly_scope_url`
  - `scores_scope_url`
- Add:
  - `lineitem_readonly_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem.readonly"`

### 3.2 Types
- Expand `LineItem`:
  - `id: Option(String)`
  - `score_maximum: Float`
  - `label: String`
  - `resource_id: String`
  - `resource_link_id: Option(String)`
  - `tag: Option(String)`
  - `start_date_time: Option(String)`
  - `end_date_time: Option(String)`
  - `grades_released: Option(Bool)`
- Add `Result` type in `src/lightbulb/services/ags/result.gleam`:
  - `id: Option(String)`
  - `user_id: String`
  - `result_score: Option(Float)`
  - `result_maximum: Option(Float)`
  - `comment: Option(String)`
  - `score_of: Option(String)`
- Add query/filter types:
  - `LineItemsQuery(resource_link_id: Option(String), resource_id: Option(String), tag: Option(String), limit: Option(Int))`
  - `ResultsQuery(user_id: Option(String), limit: Option(Int))`
- Add paging type:
  - `PageLinks(next: Option(String), prev: Option(String), first: Option(String), last: Option(String))`
  - `Paged(a)(items: List(a), links: PageLinks)`

### 3.3 Operations
Additive APIs to add in `src/lightbulb/services/ags.gleam`:
- `get_line_item(http_provider, line_item_url, access_token) -> Result(LineItem, String)`
- `list_line_items(http_provider, line_items_service_url, query, access_token) -> Result(Paged(LineItem), String)`
- `update_line_item(http_provider, line_item, access_token) -> Result(LineItem, String)`
- `delete_line_item(http_provider, line_item_url, access_token) -> Result(Nil, String)`
- `list_results(http_provider, line_item_url, query, access_token) -> Result(Paged(Result), String)`

Keep compatibility wrappers:
- Preserve existing `create_line_item`, `fetch_or_create_line_item`, `post_score` signatures.
- Existing helpers may internally call new generic operations.

## 4. HTTP Contract and Media Types

### 4.1 Line Item Service
- List line items:
  - `GET <lineitems_url>?resource_link_id=...&resource_id=...&tag=...&limit=...`
  - `Accept: application/vnd.ims.lis.v2.lineitemcontainer+json`
  - Response: `200` + line item container payload
- Get line item:
  - `GET <lineitem_url>`
  - `Accept: application/vnd.ims.lis.v2.lineitem+json`
  - Response: `200`
- Create line item:
  - `POST <lineitems_url>`
  - `Content-Type: application/vnd.ims.lis.v2.lineitem+json`
  - `Accept: application/vnd.ims.lis.v2.lineitem+json`
  - Response: `201` (support `200` for tolerance)
- Update line item:
  - `PUT <lineitem_url>`
  - `Content-Type: application/vnd.ims.lis.v2.lineitem+json`
  - `Accept: application/vnd.ims.lis.v2.lineitem+json`
  - Response: `200` (tolerate `201`)
- Delete line item:
  - `DELETE <lineitem_url>`
  - Response: `204` (tolerate `200`)

### 4.2 Score Service
- `POST <lineitem_url>/scores`
- `Content-Type: application/vnd.ims.lis.v1.score+json`
- Accept header should not force line item container media type.
- Success responses: accept `200`, `201`, `202`, `204`.

### 4.3 Result Service
- `GET <lineitem_url>/results?user_id=...&limit=...`
- `Accept: application/vnd.ims.lis.v2.resultcontainer+json`
- Response: `200` + result container payload

## 5. Scope Authorization Matrix
- Read line items (`get/list`): requires `lineitem` or `lineitem.readonly`.
- Write line items (`create/update/delete`): requires `lineitem`.
- Post score: requires `score`.
- Read results: requires `result.readonly`.

Add explicit helper predicates:
- `can_read_line_items(claims)`
- `can_write_line_items(claims)`
- `can_post_scores(claims)`
- `can_read_results(claims)`

`grade_passback_available` should be redefined to reflect score-posting capability (score scope), not results-read capability.

## 6. Paging Design
- Add shared parser module `src/lightbulb/http/link_header.gleam`.
- Parse standard relations: `next`, `prev`, `first`, `last`.
- Container list APIs (`list_line_items`, `list_results`) return `Paged(a)` with parsed links.
- If parsing fails, operation still returns items with empty links and logs parse warning.

## 7. Error Model
Keep public return type `Result(_, String)` for compatibility.
Use deterministic prefixed error categories:
- `ags.request.invalid_url`
- `ags.http.unexpected_status`
- `ags.decode.line_item`
- `ags.decode.result`
- `ags.scope.insufficient`
- `ags.pagination.invalid_link_header`

This preserves existing API shape while making failures debuggable and testable.

## 8. Runtime Flows

### 8.1 Launch claim to operation
1. Decode AGS claim.
2. Validate operation scope with predicate helper.
3. Resolve service URL (`lineitems`, `lineitem`, or derived `lineitem/results`, `lineitem/scores`).
4. Execute HTTP call with operation-specific headers.
5. Decode payload and paging metadata.

### 8.2 Fetch-or-create compatibility path
1. `list_line_items` with `resource_id` and `limit=1`.
2. If empty, call `create_line_item`.
3. Return first line item.

## 9. Testability Design
- Unit tests:
  - Scope helpers for all operation categories.
  - Query builder behavior with and without existing query strings.
  - Line item/result/claim decoders with optional fields.
  - Link header parser variations.
- Integration-style tests with `http_mock_provider`:
  - CRUD + results request construction and response handling.
  - Paging link extraction.
- Negative-path tests:
  - Wrong media type payload shape.
  - Unexpected status per operation.
  - Missing scope for operation.
  - Malformed Link header.

## 10. File-Level Design Impact
- `src/lightbulb/services/ags.gleam`
- `src/lightbulb/services/ags/line_item.gleam`
- `src/lightbulb/services/ags/result.gleam` (new)
- `src/lightbulb/http/link_header.gleam` (new)
- `test/lightbulb/services/ags_test.gleam`
- Potentially: `test/lightbulb/services/access_token_test.gleam` for scope-related assumptions

## 11. Certification Traceability (AGS)
Implementation and tests should explicitly map to AGS tool test objectives from the LTI 1.3 certification guide section 5.4, including:
- Claim availability and endpoint claim handling.
- Scope handling in access-token requests.
- Access-token retrieval and use for AGS calls.
- Line item creation and retrieval flows.
- Score publish flow.
- Result retrieval flow.
