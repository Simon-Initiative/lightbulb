import gleam/dict
import gleam/dynamic
import gleeunit/should
import lightbulb/deep_linking
import lightbulb/deep_linking/settings
import lightbulb/errors
import lightbulb/tool

pub fn validate_message_type_deep_linking_request_test() {
  let claims =
    dict.from_list([
      #(
        deep_linking.claim_message_type,
        dynamic.string(deep_linking.lti_message_type_deep_linking_request),
      ),
      #(settings.claim_deep_linking_settings, deep_link_settings_claim()),
    ])

  tool.validate_message_type(claims)
  |> should.equal(Ok(claims))
}

pub fn validate_message_type_deep_linking_request_missing_settings_test() {
  let claims =
    dict.from_list([
      #(
        deep_linking.claim_message_type,
        dynamic.string(deep_linking.lti_message_type_deep_linking_request),
      ),
    ])

  tool.validate_message_type(claims)
  |> should.equal(Error(errors.JwtInvalidClaim))
}

fn deep_link_settings_claim() -> dynamic.Dynamic {
  dynamic.properties([
    #(
      dynamic.string("deep_link_return_url"),
      dynamic.string("https://platform.example.com/deep_link_return"),
    ),
    #(
      dynamic.string("accept_types"),
      dynamic.list([dynamic.string("ltiResourceLink")]),
    ),
    #(
      dynamic.string("accept_presentation_document_targets"),
      dynamic.list([dynamic.string("iframe")]),
    ),
  ])
}
