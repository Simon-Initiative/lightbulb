# Functional Design Document: core

## 1. Normative References
- LTI Core 1.3: https://www.imsglobal.org/spec/lti/v1p3
- LTI 1.3 certification guide (Core tool tests): https://www.imsglobal.org/spec/lti/v1p3/cert
- OpenID Connect Core (aud/azp semantics): https://openid.net/specs/openid-connect-core-1_0.html

Key normative points used in this design:
- OIDC login request requires `iss`, `login_hint`, and `target_link_uri`; tool redirects to platform auth endpoint with required OIDC parameters.
- LTI message claim must identify launch message type.
- Resource link launch requires core claims including deployment, target link, roles, and resource link claim.
- Launch target link URI claim must match the target link URI used during login.
- `aud` may be string or array; when multiple audiences are present, `azp` rules apply.

## 2. Current Baseline and Gaps
Current code (`src/lightbulb/tool.gleam`) implements:
- OIDC login URL generation with state and nonce.
- ID token signature verification via platform JWKS.
- Deployment validation, timestamp checks (`exp`, `iat`), nonce validation.
- Message validation for `LtiResourceLinkRequest` only.

Gaps vs Core + certification readiness:
- Required launch claim validation is incomplete (version, roles, resource_link.id, target_link_uri claim).
- `aud` is decoded as string only; no array + `azp` resolution.
- No persistent login context for secure target-link consistency check.
- Nonce expiration is not enforced at validation-time in memory provider.
- Test coverage is missing for core launch (no existing `tool` tests).
- JWKS fetch request uses a non-standard Accept header value and should be normalized.

## 3. Target Public API and Contract

### 3.1 Public API Stability
Preserve existing public entry points:
- `lightbulb/tool.oidc_login(provider, params)`
- `lightbulb/tool.validate_launch(provider, params, session_state)`

Additive extensions only where needed for context persistence and stricter validation.

### 3.2 Provider Contract Evolution
Current `DataProvider` contract lacks state/login-context persistence hooks.
Required capability additions (either directly in `DataProvider` or via new provider composed into `validate_launch` path):
- Store login context by `state` at OIDC login time.
- Retrieve and consume login context by `state` at launch validation time.

Minimum context fields:
- `state`
- `target_link_uri`
- `issuer`
- `client_id`
- `nonce` (optional if nonce remains separate)
- `expires_at`

Compatibility requirement:
- Preserve current provider shape for existing users through adapters/default no-op wrappers where possible.

## 4. Required Claim Validation Matrix

### 4.1 OIDC Login Request Inputs
Validate inbound login request parameters before redirect generation:
- required: `iss`, `login_hint`, `target_link_uri`, `client_id`
- optional pass-through: `lti_message_hint`

### 4.2 Launch Token Structural and Signature Validation
- required request params: `id_token`, `state`
- verify JWT signature using platform JWK selected by header `kid`
- verify registration/deployment binding using trusted registration data and deployment lookup

### 4.3 Launch Claim Validation (Resource Link)
Enforce for `LtiResourceLinkRequest`:
- `https://purl.imsglobal.org/spec/lti/claim/message_type == "LtiResourceLinkRequest"`
- `https://purl.imsglobal.org/spec/lti/claim/version == "1.3.0"`
- `https://purl.imsglobal.org/spec/lti/claim/deployment_id` present
- `https://purl.imsglobal.org/spec/lti/claim/target_link_uri` present
- `https://purl.imsglobal.org/spec/lti/claim/resource_link.id` present
- `https://purl.imsglobal.org/spec/lti/claim/roles` present and valid list

### 4.4 Time-Based Validation
- enforce `exp` not expired
- enforce `iat` not unreasonably in future
- optional hardening: support `nbf` when present
- use configurable skew window (recommend 60s; current 2s is too strict for distributed systems)

## 5. Audience and Registration Resolution

### 5.1 Decoding Rules
Support:
- `aud` as string
- `aud` as list of strings

### 5.2 Resolution Algorithm
1. Parse `iss` from claims.
2. Parse `aud` shape.
3. If `aud` string: candidate client_id = `aud`.
4. If `aud` list:
   - if exactly one value and matches known registration client_id, use it
   - if multiple values, require `azp`; candidate client_id = `azp`
   - validate candidate client_id exists in `aud`
5. Resolve registration by `(iss, client_id)`.

### 5.3 Failure Modes
- missing/invalid `aud` -> explicit core audience error
- missing/invalid `azp` for multi-audience token -> explicit core audience error
- no matching registration -> explicit registration binding error

## 6. State, Target Link, and Nonce Semantics

### 6.1 State and Login Context
- Verify request `state` equals session/cookie state.
- Retrieve stored login context for this state and ensure not expired.
- Enforce launch `target_link_uri` claim equals stored login `target_link_uri`.

### 6.2 Nonce
- Validate nonce existence and expiry at lookup time.
- Consume nonce on successful validation attempt (one-time use).
- Distinguish nonce-not-found, nonce-expired, and nonce-replayed errors.

## 7. Message Type Handling Boundary
- Core feature validates and dispatches message type.
- For now, resource-link path must be complete here.
- Deep linking message validation/claim details are handled by `deep_linking` feature; core should still distinguish supported/unsupported message types and return deterministic errors.

## 8. Error Taxonomy
Keep `Result(_, String)` for API compatibility, but standardize error categories:
- `core.login.missing_param`
- `core.launch.missing_param`
- `core.jwt.invalid_signature`
- `core.jwt.invalid_claim`
- `core.jwt.expired`
- `core.jwt.not_yet_valid`
- `core.audience.invalid`
- `core.registration.not_found`
- `core.deployment.not_found`
- `core.state.invalid`
- `core.state.not_found`
- `core.target_link_uri.mismatch`
- `core.nonce.invalid`
- `core.nonce.expired`
- `core.message_type.unsupported`

## 9. Runtime Flows

### 9.1 OIDC Login Flow
1. Validate login request params.
2. Resolve registration.
3. Generate state + nonce.
4. Persist login context keyed by state.
5. Build redirect URL with required OIDC params.

### 9.2 Launch Validation Flow
1. Validate `id_token` + `state` presence and state equality.
2. Peek issuer/audience and resolve registration.
3. Verify JWT signature with matching JWK.
4. Validate required launch claims and message type.
5. Validate deployment, timestamps, nonce.
6. Validate target-link consistency from stored login context.
7. Return claims.

## 10. Testability Design

### 10.1 Unit Tests
- claim decoder/validator behavior by claim and message type
- audience and `azp` resolution matrix
- timestamp skew boundaries
- nonce expiry/replay behavior

### 10.2 Integration-Style Tests
- OIDC login -> launch roundtrip with persisted context
- registration/deployment binding and mismatch cases
- JWK selection by `kid`

### 10.3 Certification-Oriented Negative Tests
- missing required claims
- wrong version claim
- malformed/missing `aud` or `azp`
- invalid signature / unknown `kid`
- state mismatch and target-link mismatch
- replayed/expired nonce

## 11. File-Level Design Impact
- `src/lightbulb/tool.gleam`
- `src/lightbulb/providers/data_provider.gleam`
- `src/lightbulb/providers/memory_provider.gleam`
- `src/lightbulb/nonce.gleam` (if TTL helpers are introduced)
- `test/lightbulb/core_test.gleam` (new)
- `test/lightbulb/providers/memory_provider/*` (provider behavior expansion)

## 12. Certification Traceability (Core)
Implementation and tests should explicitly map to Core tool-test objectives in the LTI certification guide, including:
- Core launch flow success scenarios.
- Required claim validation behavior.
- Known bad-payload rejection classes.
- State, nonce, signature, and audience validation behavior.
