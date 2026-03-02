# LTI Conformance Matrix

This matrix maps implemented certification objectives to automated tests in this repository.

## Core 1.3

| Objective | Description | Evidence |
| --- | --- | --- |
| Core Launch Success | OIDC login + launch validation happy path | `test/lightbulb/core_test.gleam::successful_resource_link_launch_test` |
| Required Core Claims | Resource-link required claim checks (message type, version, deployment, target-link, resource-link.id, roles) | `test/lightbulb/core_test.gleam::missing_required_claim_failure_test`, `invalid_version_failure_test`, `unsupported_message_type_failure_test` |
| Audience and azp | `aud` string/list decoding and multi-audience `azp` requirements | `test/lightbulb/core_test.gleam::audience_single_success_test`, `audience_multi_with_azp_success_test`, `audience_multi_without_azp_failure_test`, `audience_azp_not_in_aud_failure_test` |
| Registration/Deployment Binding | Launch token registration and deployment binding checks | `test/lightbulb/core_test.gleam::deployment_mismatch_failure_test` |
| State and Target Link | Session state equality, stored login context, target-link consistency | `test/lightbulb/core_test.gleam::state_mismatch_failure_test`, `missing_state_context_failure_test`, `expired_state_context_failure_test`, `target_link_uri_mismatch_failure_test` |
| Nonce Hardening | Nonce expiry and one-time replay prevention | `test/lightbulb/core_test.gleam::expired_nonce_failure_test`, `replayed_nonce_failure_test` |
| JWT Signature/JWK Selection | Unknown `kid`, invalid signature, malformed JWKS payload rejection | `test/lightbulb/core_test.gleam::unknown_kid_failure_test`, `invalid_signature_failure_test`, `malformed_keyset_failure_test` |
| OAuth Provider Context | Login-context persistence and one-time state consumption semantics | `test/lightbulb/providers/memory_provider/login_context_test.gleam::login_context_round_trip_and_consume_test`, `test/lightbulb/core_test.gleam::missing_state_context_failure_test`, `expired_state_context_failure_test` |
| OAuth Service Token Handling | OAuth token request shape, tolerant decode, assertion hardening, and OAuth error mapping | `test/lightbulb/services/access_token_test.gleam::access_token_success_and_request_shape_test`, `tolerant_decode_missing_optional_fields_test`, `oauth_error_mapping_test`, `non_json_error_body_maps_to_http_status_error_test`, `assertion_claims_include_required_fields_and_hardened_lifetime_test`, `assertion_build_validation_errors_test`, `test/lightbulb/services/access_token_cache_test.gleam::fetch_access_token_with_cache_hit_test`, `fetch_access_token_with_cache_refresh_test` |

## AGS

| Objective | Description | Evidence |
| --- | --- | --- |
| 5.4.x Service Token Scope Interop | AGS scope set is sent in OAuth client-credentials token request and tolerated in response handling | `test/lightbulb/services/access_token_test.gleam::access_token_success_and_request_shape_test`, `tolerant_decode_missing_optional_fields_test` |
| AGS Score and Line Item Calls | AGS request methods and endpoint usage with bearer auth | `test/lightbulb/services/ags_test.gleam::post_score_test` |

## NRPS

| Objective | Description | Evidence |
| --- | --- | --- |
| 5.3.x Service Token Scope Interop | NRPS scope participates in OAuth client-credentials token request and response compatibility | `test/lightbulb/services/access_token_test.gleam::access_token_success_and_request_shape_test`, `tolerant_decode_missing_optional_fields_test` |
| NRPS Membership Retrieval | Membership container retrieval and decode with bearer auth | `test/lightbulb/services/nrps_test.gleam::fetch_memberships_test` |

## Deep Linking 2.0

| Objective | Description | Evidence |
| --- | --- | --- |
| 6.2.1 | Request/response flow | `test/lightbulb/deep_linking_test.gleam::get_deep_linking_settings_test` and `build_response_jwt_test` |
| 6.2.2 | Response format | `test/lightbulb/deep_linking_test.gleam::build_response_form_post_test` |
| 6.2.3 | Response timestamps | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` (signed token includes `iat`/`exp`) |
| 6.2.4 | Response signature | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` (signature verification with public key) |
| 6.2.5 | Required claims | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` (aud/message_type/deployment_id/data) |
| 6.2.6 | Response value affirmation support | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` + optional content-item validation tests |
