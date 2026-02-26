# Changelog

This changelog serves as release notes and is maintained as WIP until a release is cut.

## 2.0.0

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
- `validate_nonce/1` should return deterministic core nonce errors so clients can handle:
  - `core.nonce.invalid`
  - `core.nonce.expired`
  - `core.nonce.replayed`
- Client launch handling should support `aud` as string or list and provide `azp` for
  multi-audience tokens.

## 1.0.0

### Features

- Initial stable release of the Lightbulb LTI 1.3 library.

### Bug Fixes

- None noted.

### Breaking Changes

- None.
