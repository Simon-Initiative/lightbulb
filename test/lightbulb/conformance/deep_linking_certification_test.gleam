import gleam/dict
import gleam/dynamic
import gleam/option
import gleeunit/should
import lightbulb/deep_linking
import lightbulb/deep_linking/content_item
import lightbulb/deep_linking/settings
import lightbulb/errors
import lightbulb/jwk

pub fn deep_linking_fr_dl_01_missing_settings_claim_rejected_test() {
  deep_linking.get_deep_linking_settings(dict.new())
  |> should.equal(Error(errors.DeepLinkingClaimMissing))
}

pub fn deep_linking_fr_dl_02_invalid_item_type_rejected_test() {
  let assert Ok(active_jwk) = jwk.generate()

  let request_claims =
    dict.from_list([
      #("iss", dynamic.string("https://platform.example.com")),
      #(deep_linking.claim_deployment_id, dynamic.string("deployment-123")),
    ])

  let settings =
    settings.DeepLinkingSettings(
      deep_link_return_url: "https://platform.example.com/deep_link_return",
      accept_types: ["ltiResourceLink"],
      accept_presentation_document_targets: ["iframe"],
      accept_media_types: option.None,
      accept_multiple: option.Some(True),
      auto_create: option.None,
      title: option.None,
      text: option.None,
      data: option.None,
      accept_lineitem: option.None,
    )

  deep_linking.build_response_jwt(
    request_claims,
    settings,
    [content_item.link("https://example.com", option.None, option.None)],
    deep_linking.default_response_options(),
    active_jwk,
  )
  |> should.equal(Error(errors.DeepLinkingResponseInvalidItemType))
}
