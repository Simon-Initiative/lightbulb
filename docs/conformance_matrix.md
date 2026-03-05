# LTI Conformance Matrix

This matrix tracks requirement-to-implementation and requirement-to-test traceability for certification-ready implementation coverage.

## Status Lifecycle

- `not_started`: row created, implementation and tests not yet linked.
- `in_progress`: implementation and/or tests are actively in development.
- `implemented`: implementation and test references are linked and passing locally.
- `verified`: implementation and test coverage are complete and validated.

## Governance

- Row identity is immutable by `requirement_id + cert_reference + feature_slug`; update refs/status in place.

## Matrix

| requirement_id | spec_reference | cert_reference | feature_slug | implementation_refs | test_refs | status |
| --- | --- | --- | --- | --- | --- | --- |
| FR-CORE-01 | https://www.imsglobal.org/spec/lti/v1p3#message-type-and-required-claims | Core cert objective: required launch claim validation | core | src/lightbulb/tool.gleam | test/lightbulb/core_test.gleam::missing_required_claim_failure_test; test/lightbulb/core_test.gleam::invalid_version_failure_test; test/lightbulb/conformance/core_certification_test.gleam::core_fr_core_01_missing_roles_rejected_test | verified |
| FR-CORE-02 | https://www.imsglobal.org/spec/lti/v1p3#id-token | Core cert objective: audience (`aud`) and `azp` handling | core | src/lightbulb/tool.gleam | test/lightbulb/core_test.gleam::audience_single_success_test; test/lightbulb/core_test.gleam::audience_multi_with_azp_success_test; test/lightbulb/core_test.gleam::audience_multi_without_azp_failure_test | verified |
| FR-CORE-03 | https://www.imsglobal.org/spec/lti/v1p3#launch-presentation-and-message-types | Core cert objective: message type routing (`LtiResourceLinkRequest`, `LtiDeepLinkingRequest`) | core | src/lightbulb/tool.gleam | test/lightbulb/core_test.gleam::deep_linking_message_type_success_test; test/lightbulb/core_test.gleam::deep_linking_message_type_missing_settings_failure_test; test/lightbulb/conformance/core_certification_test.gleam::core_fr_core_03_invalid_message_type_rejected_test | verified |
| FR-DL-01 | https://www.imsglobal.org/spec/lti-dl/v2p0#deep-linking-request-message | Deep Linking cert objective 6.2.1 | deep_linking | src/lightbulb/deep_linking.gleam; src/lightbulb/deep_linking/settings.gleam | test/lightbulb/deep_linking_test.gleam::get_deep_linking_settings_test; test/lightbulb/conformance/deep_linking_certification_test.gleam::deep_linking_fr_dl_01_missing_settings_claim_rejected_test | verified |
| FR-DL-02 | https://www.imsglobal.org/spec/lti-dl/v2p0#deep-linking-response-message | Deep Linking cert objectives 6.2.2-6.2.6 | deep_linking | src/lightbulb/deep_linking.gleam; src/lightbulb/deep_linking/content_item.gleam | test/lightbulb/deep_linking_test.gleam::build_response_jwt_test; test/lightbulb/deep_linking_test.gleam::build_response_form_post_test; test/lightbulb/conformance/deep_linking_certification_test.gleam::deep_linking_fr_dl_02_invalid_item_type_rejected_test | verified |
| FR-AGS-01 | https://www.imsglobal.org/spec/lti-ags/v2p0#assignment-and-grade-services | AGS cert objectives 5.4.5-5.4.6 | ags | src/lightbulb/services/ags.gleam; src/lightbulb/services/ags/line_item.gleam | test/lightbulb/services/ags_test.gleam::create_line_item_test; test/lightbulb/services/ags_test.gleam::list_line_items_paging_test; test/lightbulb/services/ags_test.gleam::update_line_item_test; test/lightbulb/services/ags_test.gleam::delete_line_item_test | verified |
| FR-AGS-02 | https://www.imsglobal.org/spec/lti-ags/v2p0#score-service | AGS cert objective 5.4.7 | ags | src/lightbulb/services/ags.gleam; src/lightbulb/services/ags/score.gleam | test/lightbulb/services/ags_test.gleam::post_score_test | verified |
| FR-AGS-03 | https://www.imsglobal.org/spec/lti-ags/v2p0#result-service | AGS cert objective 5.4.8 | ags | src/lightbulb/services/ags.gleam; src/lightbulb/services/ags/result.gleam | test/lightbulb/services/ags_test.gleam::list_results_test | verified |
| FR-AGS-04 | https://www.imsglobal.org/spec/lti-ags/v2p0#permissions-and-scopes | AGS cert objectives 5.4.1-5.4.4 | ags | src/lightbulb/services/ags.gleam | test/lightbulb/services/ags_test.gleam::scope_helpers_test; test/lightbulb/conformance/ags_certification_test.gleam::ags_fr_ags_04_missing_score_scope_rejected_test | verified |
| FR-NRPS-01 | https://www.imsglobal.org/spec/lti-nrps/v2p0#name-and-role-provisioning-services | NRPS cert objective 5.3.1 | nrps | src/lightbulb/services/nrps.gleam; src/lightbulb/services/nrps/membership.gleam | test/lightbulb/services/nrps_test.gleam::get_nrps_claim_minimal_valid_test; test/lightbulb/services/nrps_test.gleam::get_nrps_claim_invalid_missing_service_versions_test | verified |
| FR-NRPS-02 | https://www.imsglobal.org/spec/lti-nrps/v2p0#membership-container-service | NRPS cert objectives 5.3.2-5.3.5 | nrps | src/lightbulb/services/nrps.gleam | test/lightbulb/services/nrps_test.gleam::options_query_serialization_test; test/lightbulb/services/nrps_paging_test.gleam::next_link_continuation_flow_test; test/lightbulb/conformance/nrps_certification_test.gleam::nrps_fr_nrps_02_missing_scope_rejected_test | verified |
| FR-PROV-01 | https://www.imsglobal.org/spec/lti/v1p3#oidc-login-request | Core cert objective: launch state and nonce provider semantics | oauth_provider | src/lightbulb/providers/data_provider.gleam; src/lightbulb/providers/memory_provider.gleam; src/lightbulb/tool.gleam | test/lightbulb/providers/memory_provider/login_context_test.gleam::login_context_round_trip_and_consume_test; test/lightbulb/core_test.gleam::replayed_nonce_failure_test | verified |
| NFR-01 | https://www.imsglobal.org/spec/lti/v1p3#security-framework | Security hardening: signature, nonce, state, timestamps | core | src/lightbulb/tool.gleam; src/lightbulb/nonce.gleam | test/lightbulb/core_test.gleam::invalid_signature_failure_test; test/lightbulb/core_test.gleam::expired_nonce_failure_test; test/lightbulb/core_test.gleam::state_mismatch_failure_test | verified |
| NFR-02 | https://www.imsglobal.org/ltiadvantage | Interoperability via tolerant optional-field decoding | oauth_provider | src/lightbulb/services/access_token.gleam; src/lightbulb/services/nrps.gleam | test/lightbulb/services/access_token_test.gleam::tolerant_decode_missing_optional_fields_test; test/lightbulb/services/nrps_test.gleam::minimal_member_decode_test | verified |
| NFR-03 | https://www.imsglobal.org/ltiadvantage | Backward compatibility wrappers preserved | oauth_provider | src/lightbulb/services/access_token.gleam; src/lightbulb/services/nrps.gleam | test/lightbulb/services/access_token_test.gleam::access_token_success_and_request_shape_test; test/lightbulb/services/nrps_test.gleam::fetch_memberships_test | verified |
| NFR-05 | https://www.imsglobal.org/ltiadvantage | Maintainable module boundaries and shared utility isolation | core | src/lightbulb/http/link_header.gleam; src/lightbulb/services/ags.gleam; src/lightbulb/services/nrps.gleam | test/lightbulb/services/ags_link_header_test.gleam::malformed_link_header_test; test/lightbulb/services/nrps_paging_test.gleam::malformed_link_header_fallback_behavior_test | verified |

## Validation Notes

Validate matrix integrity during documentation updates by checking:

- required schema columns and supported `status` values
- FR/NFR coverage in the matrix rows
- existence of all paths referenced in `implementation_refs` and `test_refs`
