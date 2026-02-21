# Functional Design Document: core

## 1. Functional Scope
- Validate required launch claims for supported Core message types.
- Resolve registrations using robust audience semantics.
- Bind launch validation to login context (`state`, `target_link_uri`).
- Enforce nonce expiration and one-time-use behavior.

## 2. Functional Architecture
### Public API
- Preserve existing launch APIs where practical.
- Introduce additive provider contract changes only as needed for state/context checks.

### Internal Design
- Centralize claim validation into message-type-specific validators.
- Use a typed audience resolver (`aud` string/array + `azp` handling).
- Persist login context at OIDC login and retrieve at launch validation.
- Validate nonce against timestamp at read time, then consume.

### Compatibility
- Keep old call patterns working through adapters where required.

## 3. Runtime Flow
1. Parse and validate request payload + state.
2. Resolve registration from issuer + audience.
3. Verify JWT signature and required claim set.
4. Validate deployment and target-link consistency.
5. Validate nonce lifetime and consume nonce.
6. Return typed claims or deterministic error.

## 4. Error Semantics
- Missing/invalid required claim errors are explicit.
- Audience mismatch and target-link mismatch errors are explicit.
- Nonce replay/expiration errors are explicit.

## 5. Testability Design
- Unit tests per claim and audience variant.
- Integration tests for login->launch roundtrip behavior.
- Negative-path security tests for bad payload classes.
