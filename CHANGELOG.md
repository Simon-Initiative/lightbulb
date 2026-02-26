# Changelog

This changelog serves as release notes and is maintained as WIP until a release is cut.

## [Unreleased] (target: 2.0.0)

### Features

- Full LTI 1.3 Core launch support with required claim validation, audience/`azp`
  handling, nonce hardening, and state/target-link consistency enforcement.
- Deep Linking support for decoding deep-link launches and building signed response
  JWT/form-post payloads.
- Service integrations for AGS and NRPS workflows.

### Bug Fixes

- Core launch validation now requires persisted login context and enforces state and
  `target_link_uri` consistency between OIDC login and launch validation.
- Core audience handling now supports `aud` as string or list and enforces `azp`
  semantics for multi-audience tokens.

### Breaking Changes

- `DataProvider` implementations must add:
  - `save_login_context(LoginContext) -> Result(Nil, String)`
  - `get_login_context(String) -> Result(LoginContext, String)`
  - `consume_login_context(String) -> Result(Nil, String)`
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

## 1.0.0

### Features

- Initial stable release of the Lightbulb LTI 1.3 library.

### Bug Fixes

- None noted.

### Breaking Changes

- None.
