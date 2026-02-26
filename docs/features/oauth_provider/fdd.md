# Functional Design Document: oauth_provider

## 1. Normative References
- 1EdTech Security Framework v1.1: https://www.imsglobal.org/spec/security/v1p1/
- OAuth 2.0 (RFC 6749): https://datatracker.ietf.org/doc/html/rfc6749
- JWT Profile for OAuth 2.0 Client Authentication (RFC 7523): https://datatracker.ietf.org/doc/html/rfc7523
- LTI 1.3 certification guide: https://www.imsglobal.org/spec/lti/v1p3/cert

Key normative points used in this design:
- Access-token request for LTI services uses OAuth client-credentials with JWT client assertion (`client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`).
- Assertion JWT claims must include `iss`, `sub`, `aud`, `iat`, `exp`, `jti`.
- Security framework indicates `aud` should identify the authorization server; when OpenID metadata provides `authorization_server`, that value should be used, else `token_endpoint`.
- OAuth token success response fields: `access_token` and `token_type` required; `expires_in` recommended; `scope` optional if unchanged.
- OAuth error response fields include `error` and optional `error_description`, `error_uri`.

## 2. Current Baseline and Gaps
Current code (`src/lightbulb/services/access_token.gleam`) implements:
- JWT client assertion generation using active JWK.
- Token request with client credentials and `scope`.
- Access-token decode requiring `access_token`, `token_type`, `expires_in`, and `scope`.

Current gaps:
- Token decode is too strict: `scope` and `expires_in` handling should be more tolerant.
- OAuth error body is ignored; all failures collapse to generic error text.
- No typed error surface for token failures.
- No token caching; repeated calls always hit token endpoint.
- Provider contracts currently do not include state/login-context persistence hooks needed by core feature.
- Token assertion audience source is currently always token endpoint; no explicit support for discovered `authorization_server` audience.

## 3. Target Public API

### 3.1 Access Token Types
- Keep `AccessToken` type, but evolve for tolerance:
  - `token: String`
  - `token_type: String`
  - `expires_in: Option(Int)` (or preserve Int with fallback default)
  - `scope: Option(String)` (or preserve String with fallback empty/requested scope)

Compatibility direction:
- Prefer explicit typed errors for public APIs:
  - `fetch_access_token(...) -> Result(AccessToken, AccessTokenError)`

### 3.2 Error Types
Add typed error representation in `src/lightbulb/services/access_token.gleam`:
- `AccessTokenError`
  - `RequestBuildError(reason: String)`
  - `HttpTransportError(reason: String)`
  - `HttpStatusError(status: Int, body: String)`
  - `OAuthError(error: String, error_description: Option(String), error_uri: Option(String))`
  - `DecodeError(reason: String)`
  - `AssertionBuildError(reason: String)`

Provide a dedicated conversion helper when string output is required by logs/UI.

### 3.3 Provider Contract Evolution
This feature owns provider-side contract changes that support core launch correctness:
- state/login-context store and retrieval
- nonce validation semantics with explicit expiration behavior

Preferred approach:
- add a dedicated provider record for session/login context (e.g., `LaunchContextProvider`) to minimize `DataProvider` churn
- provide adapter constructors to preserve current call pattern for existing users

### 3.4 Optional Token Cache API
Add optional cache utility layer (not mandatory in core request path):
- `TokenCacheKey(issuer, client_id, scopes_hash)`
- `CachedToken(token: AccessToken, expires_at_unix: Int)`
- operations:
  - `get(key) -> Option(CachedToken)`
  - `put(key, token)`
  - `invalidate(key)`

Cache behavior:
- treat token as stale when expiry within configurable refresh window (e.g., 60s)
- fallback to fresh fetch on cache miss/stale token

## 4. Request and Assertion Design

### 4.1 Token Request
POST form-urlencoded fields:
- `grant_type=client_credentials`
- `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`
- `client_assertion=<signed-jwt>`
- `scope=<space-delimited scopes>`

Headers:
- `Content-Type: application/x-www-form-urlencoded`
- `Accept: application/json`

### 4.2 Client Assertion JWT
Claims:
- `iss = client_id`
- `sub = client_id`
- `aud = authorization_server or token_endpoint`
- `iat = now`
- `exp = now + short lifetime`
- `jti = unique ID`

JWS header:
- `alg = RS256`
- `typ = JWT`
- `kid = active_jwk.kid`

Hardening:
- use short assertion TTL (e.g., 5 min) rather than current 1 hour
- keep configurable to handle platform skew while minimizing replay risk

## 5. Response Decode and Error Mapping

### 5.1 Success Response
Decode at minimum:
- `access_token` (required)
- `token_type` (required)

Tolerate absent:
- `expires_in`
- `scope`

Fallback behavior:
- if `scope` missing, preserve requested scopes in local token model when needed
- if `expires_in` missing, mark unknown and avoid cache persistence by default

### 5.2 Error Response
On non-2xx responses, parse body as OAuth error shape if possible:
- `error`
- `error_description`
- `error_uri`

If parse fails, return `HttpStatusError` with raw body.

## 6. Runtime Flows

### 6.1 Token Retrieval Flow
1. Build assertion JWT from registration and active JWK.
2. Send token request.
3. On success, decode tolerant token response.
4. On failure, parse OAuth error shape before generic fallback.
5. Return typed result or compatibility string error.

### 6.2 Token Cache Flow (Optional)
1. Build cache key from issuer/client/scopes.
2. Read cache and validate staleness.
3. On hit, return cached token.
4. On miss/stale, fetch token and update cache when expiry is known.

### 6.3 Provider Evolution Flow
1. Add provider extensions/adapters.
2. Update memory provider implementation.
3. Update core launch flow to use context provider semantics.

## 7. Error Taxonomy
Use explicit typed errors (`AccessTokenError` and related provider/context errors)
rather than dot-separated string identifiers.

Recommended `AccessTokenError` variants:
- `RequestInvalidUrl`
- `AssertionBuildFailed`
- `HttpTransportError`
- `HttpUnexpectedStatus`
- `OAuthInvalidClient`
- `OAuthInvalidScope`
- `DecodeInvalidTokenResponse`
- `ProviderContextMissing`
- `ProviderContextExpired`

If string output is needed for logging/UI compatibility, provide conversion helpers
(for example `access_token_error_to_string`).

## 8. Testability Design

### 8.1 Unit Tests
- assertion claim construction and audience selection
- tolerant token decode variants (with/without scope/expires_in)
- OAuth error body decode and mapping
- cache keying/staleness behavior

### 8.2 Integration-Style Tests
- token endpoint request construction validation via `http_mock_provider`
- compatibility path and typed path both covered
- provider adapter behavior for context persistence and retrieval

### 8.3 Negative Tests
- malformed JSON success body
- non-JSON error body
- invalid/missing assertion inputs
- transport errors and non-2xx status behavior

## 9. File-Level Design Impact
- `src/lightbulb/services/access_token.gleam`
- `src/lightbulb/providers/data_provider.gleam` (or new provider module for context)
- `src/lightbulb/providers/memory_provider.gleam`
- `src/lightbulb/providers.gleam` (if provider aggregate expands)
- `src/lightbulb/tool.gleam` (integration with context provider)
- `test/lightbulb/services/access_token_test.gleam`
- `test/lightbulb/providers/memory_provider/*`
- `test/lightbulb/oauth_provider_test.gleam` (new, optional)

## 10. Certification Traceability (OAuth/Provider)
This feature underpins certification checks that require successful service access-token handling in AGS/NRPS and robust core launch state/nonce semantics:
- access token request/response behavior
- scope handling
- provider-backed state/nonce correctness used by core validation
All related tests should map into certification rows from Core, AGS, and NRPS sections in `conformance_matrix.md`.
