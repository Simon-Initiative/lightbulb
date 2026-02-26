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

## Deep Linking 2.0

| Objective | Description | Evidence |
| --- | --- | --- |
| 6.2.1 | Request/response flow | `test/lightbulb/deep_linking_test.gleam::get_deep_linking_settings_test` and `build_response_jwt_test` |
| 6.2.2 | Response format | `test/lightbulb/deep_linking_test.gleam::build_response_form_post_test` |
| 6.2.3 | Response timestamps | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` (signed token includes `iat`/`exp`) |
| 6.2.4 | Response signature | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` (signature verification with public key) |
| 6.2.5 | Required claims | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` (aud/message_type/deployment_id/data) |
| 6.2.6 | Response value affirmation support | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` + optional content-item validation tests |
