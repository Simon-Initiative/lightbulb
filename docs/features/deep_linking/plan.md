# Implementation Plan: deep_linking

## Phase 1: Core Launch Integration and Settings Decoder

- [x] Extend `src/lightbulb/tool.gleam` message validators to support `LtiDeepLinkingRequest`.
- [x] Add `DeepLinkingSettings` type and decoder in `src/lightbulb/deep_linking/settings.gleam`:
  - [x] required fields (`deep_link_return_url`, `accept_types`, `accept_presentation_document_targets`)
  - [x] optional fields (`accept_media_types`, `accept_multiple`, `auto_create`, `title`, `text`, `data`, `accept_lineitem`)
- [x] Add helper `get_deep_linking_settings(claims)` in `src/lightbulb/deep_linking.gleam`.
- [x] Add unit tests for settings decode success/failure classes.

## Phase 2: Content Item Model and Validation Rules

- [x] Add `ContentItem` union type and encoders in `src/lightbulb/deep_linking/content_item.gleam`.
- [x] Implement content item builders:
  - [x] `link(...)`
  - [x] `lti_resource_link(...)`
- [x] Implement deep-linking response item validator:
  - [x] item type allowed by `accept_types`
  - [x] multiplicity constrained by `accept_multiple`
  - [x] lineItem payload allowed when `accept_lineitem` is true (or explicitly tolerated by policy)
- [x] Add tests for accepted/rejected item combinations.

## Phase 3: Response JWT Builder

- [x] Implement response claim builder in `src/lightbulb/deep_linking.gleam`.
- [x] Enforce required claims:
  - [x] `aud = request iss`
  - [x] message_type = `LtiDeepLinkingResponse`
  - [x] version = `1.3.0`
  - [x] deployment_id from request
- [x] Implement conditional `data` echo behavior.
- [x] Add optional response message/log/error claims support.
- [x] Implement JWT signing with active JWK (`kid`, RS256, `iat`, `exp`).
- [x] Add tests for signed token claims and signature verification.

## Phase 4: Form-Post Response Helper

- [x] Implement helper returning HTML form with:
  - [x] `action = deep_link_return_url`
  - [x] hidden input `name="JWT"`
  - [x] auto-submit behavior
- [x] Validate/normalize return URL handling and add explicit failure for invalid URL.
- [x] Add form helper tests for contract and escaping behavior.

## Phase 5: End-to-End Integration Paths

- [x] Add integration tests in `test/lightbulb/deep_linking_test.gleam`:
  - [x] launch claims -> settings decode -> item build -> response JWT
  - [x] response JWT -> form-post payload
- [x] Add coverage in `test/lightbulb/core_test.gleam` for deep-link message routing.
- [x] Add optional example endpoint flow in README or example app for proof-mode runs.

## Phase 6: Certification Coverage and Documentation

- [x] Map tests to certification guide Deep Linking section 6.2 objectives:
  - [x] `6.2.1` request/response flow
  - [x] `6.2.2` response format
  - [x] `6.2.3` response timestamps
  - [x] `6.2.4` response signature
  - [x] `6.2.5` required claims
  - [x] `6.2.6` response value affirmation support
- [x] Update `docs/complete_lti_support/conformance_matrix.md` with deep_linking rows.
- [x] Update `README.md` with deep linking usage example.

## Cross-Feature Dependencies

- `core`: deep-link request recognition and launch message-type validation is routed through core `validate_launch`.
- `oauth_provider`: active key management and signing dependencies are shared with token/assertion infrastructure.
- `ags`: optional `lineItem` payload support in deep-link content items should reuse AGS line item model decisions when available.
- `certification`: Deep Linking cert objective mappings (`6.2.x`) must be represented in conformance matrix and evidence package.

## File-Level Execution

- `src/lightbulb/tool.gleam`
- `src/lightbulb/deep_linking.gleam` (new)
- `src/lightbulb/deep_linking/settings.gleam` (new)
- `src/lightbulb/deep_linking/content_item.gleam` (new)
- `test/lightbulb/deep_linking_test.gleam` (new)
- `test/lightbulb/core_test.gleam` (new or expanded)
- `docs/complete_lti_support/conformance_matrix.md`
- `README.md`

## Definition of Done

- [x] Deep-link request settings are decoded and validated from launch claims.
- [x] Content item builders and validation constraints are implemented.
- [x] Signed deep-link response JWT builder exists with required/conditional claims.
- [x] Form-post helper emits valid `JWT` submission payload.
- [x] Deep linking integration tests pass.
- [x] Certification mapping and docs are updated.
