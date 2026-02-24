# Deep Linking Conformance Matrix

This matrix maps Deep Linking certification objectives (`6.2.x`) to automated
tests in this repository.

| Objective | Description | Evidence |
| --- | --- | --- |
| 6.2.1 | Request/response flow | `test/lightbulb/deep_linking_test.gleam::get_deep_linking_settings_test` and `build_response_jwt_test` |
| 6.2.2 | Response format | `test/lightbulb/deep_linking_test.gleam::build_response_form_post_test` |
| 6.2.3 | Response timestamps | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` (signed token includes `iat`/`exp`) |
| 6.2.4 | Response signature | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` (signature verification with public key) |
| 6.2.5 | Required claims | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` (aud/message_type/deployment_id/data) |
| 6.2.6 | Response value affirmation support | `test/lightbulb/deep_linking_test.gleam::build_response_jwt_test` + optional content-item validation tests |
