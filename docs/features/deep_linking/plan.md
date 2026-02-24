# Implementation Plan: deep_linking

## Phase 1: Core Launch Integration and Settings Decoder
- [ ] Add deep-linking constants in a dedicated module (message type, claim URLs).
- [ ] Extend `src/lightbulb/tool.gleam` message validators to support `LtiDeepLinkingRequest`.
- [ ] Add `DeepLinkingSettings` type and decoder in `src/lightbulb/deep_linking/settings.gleam`:
  - [ ] required fields (`deep_link_return_url`, `accept_types`, `accept_presentation_document_targets`)
  - [ ] optional fields (`accept_media_types`, `accept_multiple`, `auto_create`, `title`, `text`, `data`, `accept_lineitem`)
- [ ] Add helper `get_deep_linking_settings(claims)` in `src/lightbulb/deep_linking.gleam`.
- [ ] Add unit tests for settings decode success/failure classes.

## Phase 2: Content Item Model and Validation Rules
- [ ] Add `ContentItem` union type and encoders in `src/lightbulb/deep_linking/content_item.gleam`.
- [ ] Implement content item builders:
  - [ ] `link(...)`
  - [ ] `lti_resource_link(...)`
- [ ] Implement deep-linking response item validator:
  - [ ] item type allowed by `accept_types`
  - [ ] multiplicity constrained by `accept_multiple`
  - [ ] lineItem payload allowed when `accept_lineitem` is true (or explicitly tolerated by policy)
- [ ] Add tests for accepted/rejected item combinations.

## Phase 3: Response JWT Builder
- [ ] Implement response claim builder in `src/lightbulb/deep_linking.gleam`.
- [ ] Enforce required claims:
  - [ ] `aud = request iss`
  - [ ] message_type = `LtiDeepLinkingResponse`
  - [ ] version = `1.3.0`
  - [ ] deployment_id from request
- [ ] Implement conditional `data` echo behavior.
- [ ] Add optional response message/log/error claims support.
- [ ] Implement JWT signing with active JWK (`kid`, RS256, `iat`, `exp`).
- [ ] Add tests for signed token claims and signature verification.

## Phase 4: Form-Post Response Helper
- [ ] Implement helper returning HTML form with:
  - [ ] `action = deep_link_return_url`
  - [ ] hidden input `name="JWT"`
  - [ ] auto-submit behavior
- [ ] Validate/normalize return URL handling and add explicit failure for invalid URL.
- [ ] Add form helper tests for contract and escaping behavior.

## Phase 5: End-to-End Integration Paths
- [ ] Add integration tests in `test/lightbulb/deep_linking_test.gleam`:
  - [ ] launch claims -> settings decode -> item build -> response JWT
  - [ ] response JWT -> form-post payload
- [ ] Add coverage in `test/lightbulb/core_test.gleam` for deep-link message routing.
- [ ] Add optional example endpoint flow in README or example app for proof-mode runs.

## Phase 6: Certification Coverage and Documentation
- [ ] Map tests to certification guide Deep Linking section 6.2 objectives:
  - [ ] `6.2.1` request/response flow
  - [ ] `6.2.2` response format
  - [ ] `6.2.3` response timestamps
  - [ ] `6.2.4` response signature
  - [ ] `6.2.5` required claims
  - [ ] `6.2.6` response value affirmation support
- [ ] Update `docs/complete_lti_support/conformance_matrix.md` with deep_linking rows.
- [ ] Update `README.md` with deep linking usage example and migration notes.

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
- [ ] Deep-link request settings are decoded and validated from launch claims.
- [ ] Content item builders and validation constraints are implemented.
- [ ] Signed deep-link response JWT builder exists with required/conditional claims.
- [ ] Form-post helper emits valid `JWT` submission payload.
- [ ] Deep linking integration tests pass.
- [ ] Certification mapping and docs are updated.
