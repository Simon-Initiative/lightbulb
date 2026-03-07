# Functional Design Document

## 1. Design Overview
- Scope covered:
  - Add profile-aware deep-link response JWT shaping in `lightbulb`.
  - Ship built-in `Canvas` profile.
  - Add custom override hook with validation.
  - Keep existing API behavior unchanged.
- Assumptions:
  - Callers can decide which profile to use based on registration/issuer context.
  - Deep-link settings/content item validation remains centralized in `deep_linking`.

## 2. System Context and Boundaries
- In-scope components:
  - `build/packages/lightbulb/src/lightbulb/deep_linking.gleam`
  - `build/packages/lightbulb/src/lightbulb/errors.gleam`
  - `build/packages/lightbulb/test/lightbulb/deep_linking_test.gleam`
  - (optional) conformance/interoperability tests for Canvas profile.
- Out-of-scope components:
  - Platform detection heuristics inside `lightbulb`.
  - App-specific storage/config for LMS choice.

## 3. Architecture
- High-level flow:
  1. Build base standard claims (same as current behavior).
  2. Apply profile transformer (`Standard` no-op, `Canvas` transform, `Custom` transform).
  3. Validate required final claims and types.
  4. Sign JWT with existing JWK/JOSE path.
- Module responsibilities:
  - `deep_linking.gleam`:
    - Keep `build_response_jwt(...)` unchanged.
    - Add `build_response_jwt_with_profile(...)`.
    - Add profile types, claim transformation, and final claim validation.
  - `errors.gleam`:
    - Add new deep-linking error variants for profile/override invalid output.
- Runtime/supervision impact:
  - None (pure function flow).

## 4. Data Design
- Schema and migration changes:
  - None (library-level change).
- Data lifecycle:
  - In-memory claim dict transform only.
- Migration/backfill strategy:
  - None.

## 5. Interfaces and Contracts
- Internal APIs (proposed):

```gleam
pub type ResponseJwtProfile {
  Standard
  Canvas
  Custom(transform: ClaimTransform)
}

pub type ClaimTransform =
  fn(base_claims: jose.Claims, context: ResponseJwtContext)
    -> Result(jose.Claims, errors.DeepLinkingError)

pub type ResponseJwtContext {
  ResponseJwtContext(
    request_claims: jose.Claims,
    settings: DeepLinkingSettings,
    items: List(content_item.ContentItem),
    options: DeepLinkingResponseOptions,
  )
}

pub fn build_response_jwt_with_profile(
  request_claims: jose.Claims,
  settings: DeepLinkingSettings,
  items: List(content_item.ContentItem),
  options: DeepLinkingResponseOptions,
  active_jwk: Jwk,
  profile: ResponseJwtProfile,
) -> Result(String, DeepLinkingError)
```

- Backward-compatible existing API:

```gleam
pub fn build_response_jwt(
  request_claims: jose.Claims,
  settings: DeepLinkingSettings,
  items: List(content_item.ContentItem),
  options: DeepLinkingResponseOptions,
  active_jwk: Jwk,
) -> Result(String, DeepLinkingError)
```

Implementation: keep as-is, or delegate to `build_response_jwt_with_profile(..., Standard)`.

- Built-in Canvas transform behavior:
  - Start from standard base claims.
  - Read platform issuer (`request_claims["iss"]`) and client id (`request_claims["aud"]` string or first list element).
  - Set:
    - `iss = client_id`
    - `sub = client_id`
    - `aud = platform_issuer`
    - `azp = client_id`

- New errors (proposed):

```gleam
pub type DeepLinkingError {
  ...
  DeepLinkingProfileInvalid
  DeepLinkingProfileClaimMissing(claim: String)
  DeepLinkingProfileClaimInvalid(claim: String)
}
```

- Example caller usage (handoff-ready):

```gleam
import lightbulb/deep_linking

fn choose_profile(issuer: String) -> deep_linking.ResponseJwtProfile {
  case string.contains(string.lowercase(issuer), "instructure.com") {
    True -> deep_linking.Canvas
    False -> deep_linking.Standard
  }
}

let profile = choose_profile(platform_issuer)

deep_linking.build_response_jwt_with_profile(
  request_claims,
  settings,
  items,
  deep_linking.default_response_options(),
  active_jwk,
  profile,
)
```

- Example custom override usage:

```gleam
let custom_profile = deep_linking.Custom(fn(base_claims, ctx) {
  // Example: add vendor-specific claim while preserving required claims.
  Ok(dict.insert(base_claims, "https://example.com/claim/vendor", dynamic.string("x")))
})

deep_linking.build_response_jwt_with_profile(
  request_claims,
  settings,
  items,
  deep_linking.default_response_options(),
  active_jwk,
  custom_profile,
)
```

## 6. Runtime Behavior
- Request/runtime model:
  - Pure synchronous function path.
- Concurrency model:
  - Stateless; no mutable shared state.
- Failure handling/retries:
  - Return typed `DeepLinkingError` for profile transform failures.
- Timeouts/idempotency:
  - No change; signing remains deterministic per inputs/time.

## 7. Security and Compliance
- AuthN/AuthZ impact:
  - None.
- Data protection:
  - No sensitive data persistence changes.
- Audit/logging requirements:
  - Library should not log by default; document caller-side logging for profile selection + failure reason.

## 8. Observability and Operations
- Metrics:
  - Caller can track deep-link response success/failure by selected profile.
- Logs:
  - Caller should log profile name + normalized error.
- Alerts/runbooks:
  - Caller runbook should include platform fallback to `Custom` profile when unknown LMS incompatibility appears.

## 9. Testing Strategy
- Unit:
  - `Standard` profile preserves current claim outputs.
  - `Canvas` profile claim transform outputs expected identity claims.
  - `Custom` profile is invoked and transformed claims are used.
  - invalid final claim sets return typed errors.
- Contract:
  - signed JWT contains required LTI DL claims for all profiles.
  - content item and return URL validation still enforced.
- Regression:
  - Existing `build_response_jwt_test` behavior remains unchanged.
  - `build_response_form_post` tests unaffected.
- End-to-end:
  - Validate Canvas deep-link flow with `Canvas` profile.
  - Validate at least one non-Canvas LMS with `Standard` profile.

## 10. Open Questions
- Should `Canvas` be shipped as a first-class enum case or as a reusable transform helper (`deep_linking_profiles.canvas`) to reduce API surface?
- Should profile logic own issuer/client-id extraction helpers shared with core claim parsing?
- Should future profiles live in separate module(s) to avoid bloating `deep_linking.gleam`?
