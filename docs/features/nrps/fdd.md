# Functional Design Document: nrps

## 1. Normative References
- NRPS 2.0 spec: https://www.imsglobal.org/spec/lti-nrps/v2p0/
- LTI 1.3 certification guide (NRPS tool tests): https://www.imsglobal.org/spec/lti/v1p3/cert

Key normative points used in this design:
- NRPS claim URL: `https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice`
- Required claim fields include:
  - `context_memberships_url`
  - `service_versions`
- Scope for roster read: `https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly`
- Membership container returns `members` array.
- Pagination and delta patterns use HTTP `Link` headers (including `next` and `differences` relations).
- Role and resource-link scoping are represented via query parameters (including `role`, `limit`, `rlid`).

## 2. Current Baseline and Gaps
Current code (`src/lightbulb/services/nrps.gleam`) implements:
- `fetch_memberships(http_provider, context_memberships_url, access_token)`
- `nrps_available(claims)`
- `get_membership_service_url(claims)`

Current gaps:
- NRPS claim decoder currently requires non-normative fields (`errors`, `validation_context`) and ignores `service_versions`.
- Membership decoder currently requires many fields that are optional in practice; this causes decode failures for valid minimal payloads.
- No options API for role filter, limit, resource-link scoping.
- No pagination or differences-link support.
- No typed result model for paging metadata.
- `fetch_memberships` hardcodes `?limit=1000`, which is inflexible.

## 3. Target Public API

### 3.1 Constants
Keep existing:
- `nrps_claim_url`
- `context_membership_readonly_claim_url`

### 3.2 Types
- `NrpsClaim`
  - `context_memberships_url: String`
  - `service_versions: List(String)`
- `Membership` (tolerant model)
  - required:
    - `user_id: String`
    - `roles: List(String)`
  - optional:
    - `status: Option(String)`
    - `name: Option(String)`
    - `given_name: Option(String)`
    - `family_name: Option(String)`
    - `middle_name: Option(String)`
    - `email: Option(String)`
    - `picture: Option(String)`
    - `lis_person_sourcedid: Option(String)`
- `MembershipsQuery`
  - `role: Option(String)`
  - `limit: Option(Int)`
  - `rlid: Option(String)`
  - `url: Option(String)` (direct next/differences URL override for paging workflows)
- `PageLinks`
  - `next: Option(String)`
  - `differences: Option(String)`
  - `prev: Option(String)`
  - `first: Option(String)`
  - `last: Option(String)`
- `MembershipsPage`
  - `members: List(Membership)`
  - `links: PageLinks`

### 3.3 Operations
Additive API surface in `src/lightbulb/services/nrps.gleam`:
- `get_nrps_claim(claims) -> Result(NrpsClaim, NrpsError)` (make public)
- `fetch_memberships_with_options(http_provider, context_memberships_url, query, access_token) -> Result(MembershipsPage, NrpsError)`
- `fetch_next_memberships_page(http_provider, next_url, access_token) -> Result(MembershipsPage, NrpsError)`
- `fetch_differences_memberships_page(http_provider, differences_url, access_token) -> Result(MembershipsPage, NrpsError)`

Compatibility:
- Keep `fetch_memberships(...)` as wrapper around options API with default behavior, but
  return `Result(List(Membership), NrpsError)`.

## 4. Claim and Scope Validation Rules

### 4.1 NRPS Claim Decode Rules
- Required:
  - `context_memberships_url` string
  - `service_versions` list of strings
- Ignore unknown extra fields.
- Do not require non-normative fields.

### 4.2 Scope Availability
Add helper predicate:
- `can_read_memberships(claims) -> Bool`

Behavior:
- Returns true only when NRPS claim exists and scope list includes `contextmembership.readonly`.

## 5. Membership Decode Rules
- Required fields for each member:
  - `user_id`
  - `roles`
- All other fields optional.
- If `status` missing, preserve as `None` or optionally map default in helper layer (do not force decoder failure).
- Decoder must tolerate additional unknown member fields.

## 6. HTTP Contract and Query Behavior

### 6.1 Headers
- Request:
  - `Authorization: Bearer <token>`
  - `Accept: application/vnd.ims.lti-nrps.v2.membershipcontainer+json`
- `Content-Type` is not required for GET and should not be mandatory.

### 6.2 Request URL Construction
Base URL path:
- `context_memberships_url`

Supported query params:
- `role`
- `limit`
- `rlid`

If `query.url` is provided (next/differences continuation), use that URL directly and ignore base/query construction.

### 6.3 Response Handling
- Success status: `200` (tolerate `201` for robustness)
- Decode body as membership container.
- Parse `Link` headers into `PageLinks`.
- If link header parsing fails, still return decoded members with empty links and log warning.

## 7. Paging and Differences Design
- Reuse shared `src/lightbulb/http/link_header.gleam` parser.
- Parse and expose link relations used by NRPS workflows:
  - `next`
  - `differences`
  - optionally `prev`, `first`, `last`
- Provide convenience methods for consuming continuation links.

## 8. Error Taxonomy
Use explicit NRPS error types for public APIs (for example `NrpsError`) rather than
string identifiers.

Recommended variants:
- `ClaimMissing`
- `ClaimInvalid`
- `ScopeInsufficient`
- `RequestInvalidUrl`
- `HttpUnexpectedStatus`
- `DecodeMembershipContainer`
- `DecodeMember`
- `PaginationInvalidLinkHeader`

If string output is needed for logging/UI compatibility, provide a dedicated conversion
function (for example `nrps_error_to_string`).

## 9. Runtime Flows

### 9.1 Launch Claims to NRPS Availability
1. Decode NRPS claim.
2. Validate read scope presence.
3. Extract membership service URL.

### 9.2 Membership Fetch with Options
1. Build URL from base + query options, unless continuation URL is explicitly provided.
2. Issue authenticated GET request.
3. Decode members and parse link headers.
4. Return `MembershipsPage`.

### 9.3 Compatibility Wrapper
1. `fetch_memberships` calls `fetch_memberships_with_options` with default query.
2. Returns only `members` list, discarding paging metadata.

## 10. Testability Design

### 10.1 Unit Tests
- claim decode for required fields and unknown-field tolerance
- membership decode for minimal and expanded payloads
- query builder behavior (`role`, `limit`, `rlid`)
- link-header parsing for `next` and `differences`

### 10.2 Integration-Style Tests
- one-page roster flow with optional fields
- multi-page flow following `next`
- differences flow following `differences`

### 10.3 Negative Tests
- missing claim fields
- malformed member object (`roles` wrong type, missing `user_id`)
- invalid URL and unexpected status
- malformed Link header

## 11. File-Level Design Impact
- `src/lightbulb/services/nrps.gleam`
- `src/lightbulb/services/nrps/membership.gleam`
- `src/lightbulb/http/link_header.gleam` (reuse/add if created by AGS)
- `test/lightbulb/services/nrps_test.gleam`
- `test/lightbulb/services/nrps_paging_test.gleam` (new)

## 12. Certification Traceability (NRPS)
Implementation and tests should explicitly map to NRPS tool-test objectives in the certification guide section 5.3, including:
- NRPS claim presence and claim URL handling
- scope handling for access-token request and use
- membership retrieval behavior
- role-specific membership retrieval behavior
