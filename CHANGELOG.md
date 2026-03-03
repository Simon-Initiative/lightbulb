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
  - `services/access_token.fetch_access_token/3`
  - `services/access_token.fetch_access_token_with_options/4`
  - `services/access_token.access_token_error_to_string/1`
- Optional OAuth token cache helper:
  - `services/access_token_cache` with cache keying, staleness checks, and
    `fetch_access_token_with_cache/4`.
- Provider composition helper for login context:
  - `providers/data_provider.LaunchContextProvider`
  - `providers/data_provider.from_parts/6`
- Replaced custom internal logger FFI implementation with the `logging` (`v1.3.0`)
  package while preserving `lightbulb/utils/logger` call sites.
- AGS API expansion and hardening (target: `2.0.0`):
  - New typed AGS errors and string conversion helper:
    `services/ags.AgsError`, `services/ags.ags_error_to_string/1`
  - Full line item service coverage:
    `get_line_item/3`, `list_line_items/4`, `update_line_item/3`,
    `delete_line_item/3`, `create_line_item/6`,
    `fetch_or_create_line_item/7`
  - Results service support:
    `list_results/4` with `ResultsQuery`
  - Paging metadata support:
    `http/link_header` parser and `services/ags.Paged(a)` responses
  - Scope helpers and guards:
    `can_*` and `require_can_*` predicates for line items/scores/results
  - Added AGS readonly line-item scope constant:
    `lineitem_readonly_scope_url`
- NRPS API expansion and hardening (target: `2.0.0`):
  - New typed NRPS errors and conversion helper:
    `services/nrps.NrpsError`, `services/nrps.nrps_error_to_string/1`
  - Spec-aligned NRPS claim decoding:
    `services/nrps.get_nrps_claim/1` now requires
    `context_memberships_url` and `service_versions`
  - Scope helpers:
    `can_read_memberships/1`, `require_can_read_memberships/1`
  - Options-based membership fetch and paging support:
    `MembershipsQuery`, `MembershipsPage`,
    `fetch_memberships_with_options/4`,
    `fetch_next_memberships_page/3`,
    `fetch_differences_memberships_page/3`
  - Compatibility wrapper retained:
    `fetch_memberships/3` still returns `List(Membership)` via default options.
- Certification governance package (target: `2.0.0`):
  - Added schema-driven conformance matrix:
    `docs/complete_lti_support/conformance_matrix.md`
  - Added certification runbook:
    `docs/complete_lti_support/certification_runbook.md`
  - Added evidence package layout and dry-run records under:
    `docs/complete_lti_support/evidence/`
  - Added matrix lint automation:
    `scripts/lint_conformance_matrix.sh`
  - Added conformance-focused test modules under:
    `test/lightbulb/conformance/`
  - CI now enforces matrix lint in `.github/workflows/test.yml`.

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
- AGS score posting now accepts `200/201/202/204` success statuses and no longer
  sends the line-item-container `Accept` header for score POST requests.
- `grade_passback_available/1` now reflects score-posting capability (`scope/score`)
  instead of results-read capability.
- NRPS membership decode now tolerates minimal valid member payloads and no longer
  requires non-normative claim fields (`errors`, `validation_context`).

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
- AGS `LineItem` constructor now includes additional optional AGS fields:
  `resource_link_id`, `tag`, `start_date_time`, `end_date_time`,
  `grades_released`.
- Migration for OAuth callers:
  - `fetch_access_token/3` now returns typed errors:
    `Result(AccessToken, AccessTokenError)`.
  - If you need user-facing string messages, convert with
    `access_token_error_to_string/1` at process boundaries.
  - If you need custom assertion audience or TTL, switch to
    `fetch_access_token_with_options/4`.
  - To reduce token endpoint traffic, adopt `services/access_token_cache` and route
    service-token fetches through `fetch_access_token_with_cache/4`.
- Migration for AGS callers:
  - AGS APIs return typed errors (`AgsError`) and no longer provide
    string-error compatibility wrappers.
  - Pattern-match on `AgsError`, or convert with `ags_error_to_string/1`
    at process boundaries.
  - If you construct `LineItem` directly, add the new optional fields with
    `option.None` unless needed.
- Migration for NRPS callers:
  - `fetch_memberships/3` now returns `Result(List(Membership), NrpsError)`
    (typed errors instead of string errors).
  - Pattern-match on `NrpsError`, or convert at process boundaries with
    `nrps_error_to_string/1`.
  - If you construct `Membership` directly, use the new shape:
    required: `user_id`, `roles`; optional: `status`, `name`, `given_name`,
    `family_name`, `middle_name`, `email`, `picture`, `lis_person_sourcedid`.
  - For filtering/paging flows, move from `fetch_memberships/3` to
    `fetch_memberships_with_options/4` and continuation helpers.
- Migration for maintainers (certification workflow):
  - Run `scripts/lint_conformance_matrix.sh` before `gleam test`.
  - Keep requirement rows and test/evidence refs current in
    `docs/complete_lti_support/conformance_matrix.md`.
  - Capture dated evidence artifacts in
    `docs/complete_lti_support/evidence/` and update
    `last_verified_date` on affected rows.

## 1.0.0

### Features

- Initial stable release of the Lightbulb LTI 1.3 library.

### Bug Fixes

- None noted.

### Breaking Changes

- None.
