# Changelog

This changelog serves as release notes and is maintained as WIP until a release is cut.

## [Unreleased] (target: 2.0.0)

### Features

- Full LTI 1.3 Core launch support with required claim validation, audience/`azp`
  handling, nonce hardening, and state/target-link consistency enforcement.
- Deep Linking support for decoding deep-link launches and building signed response
  JWT/form-post payloads.
- Service integrations for AGS and NRPS workflows.
- OAuth service token typed API and error taxonomy:
  - `services/access_token.fetch_access_token_typed/3`
  - `services/access_token.fetch_access_token_with_options/4`
  - `services/access_token.access_token_error_to_string/1`
- Optional OAuth token cache helper:
  - `services/access_token_cache` with cache keying, staleness checks, and
    `fetch_access_token_with_cache/4`.
- Provider composition helper for login context:
  - `providers/data_provider.LaunchContextProvider`
  - `providers/data_provider.from_parts/6`

### Bug Fixes

- Core launch validation now requires persisted login context and enforces state and
  `target_link_uri` consistency between OIDC login and launch validation.
- Core audience handling now supports `aud` as string or list and enforces `azp`
  semantics for multi-audience tokens.
- OAuth token decode now tolerates missing `scope` and `expires_in` fields while
  preserving usable defaults.
- Non-2xx OAuth token responses now parse RFC 6749-style error bodies
  (`error`, `error_description`, `error_uri`) before falling back to generic status
  errors.
- OAuth client assertion defaults are hardened with short lifetime defaults (5 minutes)
  and configurable audience selection.
- Replaced the `birl` dependency with direct use of `gleam/time` (`duration` and
  `timestamp`) for nonce/login-context expiry and JWT timestamp handling.

### Breaking Changes

- `DataProvider` implementations must add:
  - `save_login_context(LoginContext) -> Result(Nil, LaunchContextError)`
  - `get_login_context(String) -> Result(LoginContext, LaunchContextError)`
  - `consume_login_context(String) -> Result(Nil, LaunchContextError)`
- `DataProvider` provider operations now use typed provider errors:
  - `create_nonce() -> Result(Nonce, ProviderError)`
  - `get_registration(String, String) -> Result(Registration, ProviderError)`
  - `get_deployment(String, String, String) -> Result(Deployment, ProviderError)`
  - `get_active_jwk() -> Result(Jwk, ProviderError)`
- Core APIs now return structured error types instead of string codes:
  - `tool.oidc_login/2 -> Result(#(String, String), CoreError)`
  - `tool.validate_launch/3 -> Result(Claims, CoreError)`
  - `tool.validate_message_type/1 -> Result(Claims, CoreError)`
- Deep Linking APIs now return `DeepLinkingError` instead of string error IDs:
  - `deep_linking.get_deep_linking_settings/1`
  - `deep_linking.build_response_jwt/5`
  - `deep_linking.build_response_form_post/2`
  - `deep_linking/content_item.validate_items/2`
- `DataProvider.validate_nonce/1` now returns `Result(Nil, NonceError)` and must map
  nonce outcomes to explicit variants (`NonceInvalid`, `NonceExpired`, `NonceReplayed`).
- Clients relying on string matching should migrate to variant matching, or explicitly
  convert to short user-facing messages via `lightbulb/errors.{core_error_to_string}`
  and `lightbulb/errors.{nonce_error_to_string}`.
- For deep-linking user-facing messages, use
  `lightbulb/errors.{deep_linking_error_to_string}`.
- Migration for OAuth callers:
  - Existing `fetch_access_token/3` remains supported.
  - Prefer `fetch_access_token_typed/3` for structured handling and map to strings only
    at process boundaries with `access_token_error_to_string/1`.
  - If you need custom assertion audience or TTL, switch to
    `fetch_access_token_with_options/4`.
  - To reduce token endpoint traffic, adopt `services/access_token_cache` and route
    service-token fetches through `fetch_access_token_with_cache/4`.

## 1.0.0

### Features

- Initial stable release of the Lightbulb LTI 1.3 library.

### Bug Fixes

- None noted.

### Breaking Changes

- None.
