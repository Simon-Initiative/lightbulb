import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/option
import gleam/result
import gleam/string
import gleeunit/should
import lightbulb/deep_linking
import lightbulb/deep_linking/content_item
import lightbulb/deep_linking/settings.{DeepLinkingSettings}
import lightbulb/errors
import lightbulb/jose
import lightbulb/jwk

pub fn get_deep_linking_settings_test() {
  let claims =
    dict.from_list([
      #(settings.claim_deep_linking_settings, dynamic_settings_claim()),
    ])

  let assert Ok(settings) = deep_linking.get_deep_linking_settings(claims)

  settings.deep_link_return_url
  |> should.equal("https://platform.example.com/deep_link_return")

  settings.accept_types
  |> should.equal(["ltiResourceLink", "link"])

  settings.accept_multiple
  |> should.equal(option.Some(True))
}

pub fn get_deep_linking_settings_missing_claim_test() {
  deep_linking.get_deep_linking_settings(dict.new())
  |> should.equal(Error(errors.DeepLinkingClaimMissing))
}

pub fn build_response_jwt_test() {
  let assert Ok(active_jwk) = jwk.generate()

  let request_claims =
    dict.from_list([
      #("iss", dynamic.string("https://platform.example.com")),
      #(deep_linking.claim_deployment_id, dynamic.string("deployment-123")),
    ])

  let assert Ok(settings) =
    deep_linking.get_deep_linking_settings(
      dict.from_list([
        #(settings.claim_deep_linking_settings, dynamic_settings_claim()),
      ]),
    )

  let items = [
    content_item.lti_resource_link(
      option.Some("https://tool.example.com/launch/abc"),
      option.Some("Unit 1"),
      option.Some("Open Unit 1"),
      option.Some(dict.from_list([#("chapter", "1")])),
      option.Some(content_item.LineItem(
        score_maximum: 100.0,
        resource_id: option.Some("resource-1"),
        tag: option.Some("graded"),
        label: option.Some("Unit 1 Grade"),
        grades_released: option.Some(True),
      )),
    ),
  ]

  let options =
    deep_linking.DeepLinkingResponseOptions(
      msg: option.Some("Ready"),
      log: option.None,
      errormsg: option.None,
      errorlog: option.None,
      ttl_seconds: 60,
    )

  let assert Ok(jwt) =
    deep_linking.build_response_jwt(
      request_claims,
      settings,
      items,
      options,
      active_jwk,
    )

  let #(_, public_jwk_map) = active_jwk |> jwk.to_map()
  let #(verified, verified_jwt, verified_jws) =
    jose.verify(jose.to_public(jose.from_map(public_jwk_map)), jwt)

  verified
  |> should.be_true()

  decode_claim_string(verified_jwt.claims, "aud")
  |> should.equal(Ok("https://platform.example.com"))

  decode_claim_string(verified_jwt.claims, deep_linking.claim_message_type)
  |> should.equal(Ok(deep_linking.lti_message_type_deep_linking_response))

  decode_claim_string(verified_jwt.claims, deep_linking.claim_deployment_id)
  |> should.equal(Ok("deployment-123"))

  decode_claim_string(verified_jwt.claims, deep_linking.claim_data)
  |> should.equal(Ok("opaque-platform-data"))

  decode_claim_string(verified_jwt.claims, deep_linking.claim_msg)
  |> should.equal(Ok("Ready"))

  decode_claim_string(verified_jws.headers, "kid")
  |> should.equal(Ok(active_jwk.kid))
}

pub fn build_response_jwt_with_standard_profile_test() {
  let assert Ok(active_jwk) = jwk.generate()

  let request_claims =
    dict.from_list([
      #("iss", dynamic.string("https://platform.example.com")),
      #("aud", dynamic.string("tool-client-id")),
      #(deep_linking.claim_deployment_id, dynamic.string("deployment-123")),
    ])

  let assert Ok(settings) =
    deep_linking.get_deep_linking_settings(
      dict.from_list([
        #(settings.claim_deep_linking_settings, dynamic_settings_claim()),
      ]),
    )

  let assert Ok(jwt) =
    deep_linking.build_response_jwt_with_profile(
      request_claims,
      settings,
      [],
      deep_linking.default_response_options(),
      active_jwk,
      deep_linking.Standard,
    )

  let #(_, public_jwk_map) = active_jwk |> jwk.to_map()
  let #(verified, verified_jwt, _) =
    jose.verify(jose.to_public(jose.from_map(public_jwk_map)), jwt)

  verified
  |> should.be_true()

  decode_claim_string(verified_jwt.claims, "aud")
  |> should.equal(Ok("https://platform.example.com"))

  decode_claim_string(verified_jwt.claims, "iss")
  |> should.equal(Error("missing"))

  decode_claim_string(verified_jwt.claims, "azp")
  |> should.equal(Error("missing"))
}

pub fn build_response_jwt_with_canvas_profile_test() {
  let assert Ok(active_jwk) = jwk.generate()

  let request_claims =
    dict.from_list([
      #("iss", dynamic.string("https://canvas.instructure.com")),
      #("aud", dynamic.list([dynamic.string("canvas-client-id")])),
      #(deep_linking.claim_deployment_id, dynamic.string("deployment-123")),
    ])

  let assert Ok(settings) =
    deep_linking.get_deep_linking_settings(
      dict.from_list([
        #(settings.claim_deep_linking_settings, dynamic_settings_claim()),
      ]),
    )

  let assert Ok(jwt) =
    deep_linking.build_response_jwt_with_profile(
      request_claims,
      settings,
      [],
      deep_linking.default_response_options(),
      active_jwk,
      deep_linking.Canvas,
    )

  let #(_, public_jwk_map) = active_jwk |> jwk.to_map()
  let #(verified, verified_jwt, _) =
    jose.verify(jose.to_public(jose.from_map(public_jwk_map)), jwt)

  verified
  |> should.be_true()

  decode_claim_string(verified_jwt.claims, "iss")
  |> should.equal(Ok("canvas-client-id"))

  decode_claim_string(verified_jwt.claims, "sub")
  |> should.equal(Ok("canvas-client-id"))

  decode_claim_string(verified_jwt.claims, "azp")
  |> should.equal(Ok("canvas-client-id"))

  decode_claim_string(verified_jwt.claims, "aud")
  |> should.equal(Ok("https://canvas.instructure.com"))
}

pub fn build_response_jwt_with_canvas_profile_missing_issuer_test() {
  let assert Ok(active_jwk) = jwk.generate()

  let request_claims =
    dict.from_list([
      #("aud", dynamic.string("canvas-client-id")),
      #(deep_linking.claim_deployment_id, dynamic.string("deployment-123")),
    ])

  let assert Ok(settings) =
    deep_linking.get_deep_linking_settings(
      dict.from_list([
        #(settings.claim_deep_linking_settings, dynamic_settings_claim()),
      ]),
    )

  deep_linking.build_response_jwt_with_profile(
    request_claims,
    settings,
    [],
    deep_linking.default_response_options(),
    active_jwk,
    deep_linking.Canvas,
  )
  |> should.equal(Error(errors.DeepLinkingClaimMissing))
}

pub fn build_response_jwt_with_canvas_profile_invalid_aud_list_test() {
  let assert Ok(active_jwk) = jwk.generate()

  let request_claims =
    dict.from_list([
      #("iss", dynamic.string("https://canvas.instructure.com")),
      #("aud", dynamic.list([])),
      #(deep_linking.claim_deployment_id, dynamic.string("deployment-123")),
    ])

  let assert Ok(settings) =
    deep_linking.get_deep_linking_settings(
      dict.from_list([
        #(settings.claim_deep_linking_settings, dynamic_settings_claim()),
      ]),
    )

  deep_linking.build_response_jwt_with_profile(
    request_claims,
    settings,
    [],
    deep_linking.default_response_options(),
    active_jwk,
    deep_linking.Canvas,
  )
  |> should.equal(Error(errors.DeepLinkingProfileClaimInvalid("aud")))
}

pub fn build_response_jwt_with_custom_profile_test() {
  let assert Ok(active_jwk) = jwk.generate()

  let request_claims =
    dict.from_list([
      #("iss", dynamic.string("https://platform.example.com")),
      #("aud", dynamic.string("tool-client-id")),
      #(deep_linking.claim_deployment_id, dynamic.string("deployment-123")),
    ])

  let assert Ok(settings) =
    deep_linking.get_deep_linking_settings(
      dict.from_list([
        #(settings.claim_deep_linking_settings, dynamic_settings_claim()),
      ]),
    )

  let custom_profile: deep_linking.ResponseJwtProfile =
    deep_linking.Custom(fn(base_claims, _context) {
      Ok(dict.insert(base_claims, "iss", dynamic.string("custom-issuer")))
    })

  let assert Ok(jwt) =
    deep_linking.build_response_jwt_with_profile(
      request_claims,
      settings,
      [],
      deep_linking.default_response_options(),
      active_jwk,
      custom_profile,
    )

  let #(_, public_jwk_map) = active_jwk |> jwk.to_map()
  let #(verified, verified_jwt, _) =
    jose.verify(jose.to_public(jose.from_map(public_jwk_map)), jwt)

  verified
  |> should.be_true()

  decode_claim_string(verified_jwt.claims, "iss")
  |> should.equal(Ok("custom-issuer"))
}

pub fn build_response_jwt_with_custom_profile_invalid_output_test() {
  let assert Ok(active_jwk) = jwk.generate()

  let request_claims =
    dict.from_list([
      #("iss", dynamic.string("https://platform.example.com")),
      #("aud", dynamic.string("tool-client-id")),
      #(deep_linking.claim_deployment_id, dynamic.string("deployment-123")),
    ])

  let assert Ok(settings) =
    deep_linking.get_deep_linking_settings(
      dict.from_list([
        #(settings.claim_deep_linking_settings, dynamic_settings_claim()),
      ]),
    )

  let custom_profile: deep_linking.ResponseJwtProfile =
    deep_linking.Custom(fn(base_claims, _context) {
      Ok(dict.delete(base_claims, "aud"))
    })

  deep_linking.build_response_jwt_with_profile(
    request_claims,
    settings,
    [],
    deep_linking.default_response_options(),
    active_jwk,
    custom_profile,
  )
  |> should.equal(Error(errors.DeepLinkingProfileClaimMissing("aud")))
}

pub fn build_response_jwt_with_custom_profile_failure_mapped_test() {
  let assert Ok(active_jwk) = jwk.generate()

  let request_claims =
    dict.from_list([
      #("iss", dynamic.string("https://platform.example.com")),
      #("aud", dynamic.string("tool-client-id")),
      #(deep_linking.claim_deployment_id, dynamic.string("deployment-123")),
    ])

  let assert Ok(settings) =
    deep_linking.get_deep_linking_settings(
      dict.from_list([
        #(settings.claim_deep_linking_settings, dynamic_settings_claim()),
      ]),
    )

  let custom_profile: deep_linking.ResponseJwtProfile =
    deep_linking.Custom(fn(_base_claims, _context) {
      Error(errors.DeepLinkingClaimInvalid)
    })

  deep_linking.build_response_jwt_with_profile(
    request_claims,
    settings,
    [],
    deep_linking.default_response_options(),
    active_jwk,
    custom_profile,
  )
  |> should.equal(Error(errors.DeepLinkingProfileInvalid))
}

pub fn build_response_jwt_rejects_invalid_item_type_test() {
  let assert Ok(active_jwk) = jwk.generate()

  let request_claims =
    dict.from_list([
      #("iss", dynamic.string("https://platform.example.com")),
      #(deep_linking.claim_deployment_id, dynamic.string("deployment-123")),
    ])

  let settings =
    DeepLinkingSettings(
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

  let result =
    deep_linking.build_response_jwt(
      request_claims,
      settings,
      [content_item.link("https://example.com", option.None, option.None)],
      deep_linking.default_response_options(),
      active_jwk,
    )

  result
  |> should.equal(Error(errors.DeepLinkingResponseInvalidItemType))
}

pub fn validate_items_accepts_allowed_type_and_count_test() {
  let settings =
    DeepLinkingSettings(
      deep_link_return_url: "https://platform.example.com/deep_link_return",
      accept_types: ["link"],
      accept_presentation_document_targets: ["iframe"],
      accept_media_types: option.None,
      accept_multiple: option.Some(False),
      auto_create: option.None,
      title: option.None,
      text: option.None,
      data: option.None,
      accept_lineitem: option.None,
    )

  content_item.validate_items(settings, [
    content_item.link(
      "https://example.com/resource-1",
      option.None,
      option.None,
    ),
  ])
  |> should.equal(Ok(Nil))
}

pub fn validate_items_rejects_multiple_when_not_allowed_test() {
  let settings =
    DeepLinkingSettings(
      deep_link_return_url: "https://platform.example.com/deep_link_return",
      accept_types: ["link"],
      accept_presentation_document_targets: ["iframe"],
      accept_media_types: option.None,
      accept_multiple: option.Some(False),
      auto_create: option.None,
      title: option.None,
      text: option.None,
      data: option.None,
      accept_lineitem: option.None,
    )

  content_item.validate_items(settings, [
    content_item.link(
      "https://example.com/resource-1",
      option.None,
      option.None,
    ),
    content_item.link(
      "https://example.com/resource-2",
      option.None,
      option.None,
    ),
  ])
  |> should.equal(Error(errors.DeepLinkingResponseMultipleNotAllowed))
}

pub fn validate_items_rejects_line_item_when_not_allowed_test() {
  let settings =
    DeepLinkingSettings(
      deep_link_return_url: "https://platform.example.com/deep_link_return",
      accept_types: ["ltiResourceLink"],
      accept_presentation_document_targets: ["iframe"],
      accept_media_types: option.None,
      accept_multiple: option.Some(True),
      auto_create: option.None,
      title: option.None,
      text: option.None,
      data: option.None,
      accept_lineitem: option.Some(False),
    )

  let items = [
    content_item.lti_resource_link(
      option.Some("https://tool.example.com/launch/resource-1"),
      option.Some("Resource 1"),
      option.None,
      option.None,
      option.Some(content_item.LineItem(
        score_maximum: 10.0,
        resource_id: option.Some("resource-1"),
        tag: option.None,
        label: option.Some("Grade"),
        grades_released: option.None,
      )),
    ),
  ]

  content_item.validate_items(settings, items)
  |> should.equal(Error(errors.DeepLinkingResponseInvalidItemType))
}

pub fn build_response_form_post_test() {
  let assert Ok(html) =
    deep_linking.build_response_form_post(
      "https://platform.example.com/deep_link_return",
      "header.payload.signature",
    )

  string.contains(html, "name=\"JWT\"")
  |> should.be_true()

  string.contains(html, "header.payload.signature")
  |> should.be_true()

  string.contains(
    html,
    "action=\"https://platform.example.com/deep_link_return\"",
  )
  |> should.be_true()
}

pub fn build_response_form_post_contract_test() {
  let assert Ok(html) =
    deep_linking.build_response_form_post(
      "https://platform.example.com/deep_link_return",
      "header.payload.signature",
    )

  string.contains(
    html,
    "<form id=\"deep-linking-form\" action=\"https://platform.example.com/deep_link_return\" method=\"POST\">",
  )
  |> should.be_true()

  string.contains(
    html,
    "<input type=\"hidden\" name=\"JWT\" value=\"header.payload.signature\"/>",
  )
  |> should.be_true()

  string.contains(
    html,
    "<script>document.getElementById('deep-linking-form').submit();</script>",
  )
  |> should.be_true()
}

pub fn build_response_form_post_escapes_action_and_jwt_test() {
  let assert Ok(html) =
    deep_linking.build_response_form_post(
      "https://platform.example.com/deep_link_return?x=1&y=2",
      "abc<def>&\"ghi\"",
    )

  string.contains(
    html,
    "action=\"https://platform.example.com/deep_link_return?x=1&amp;y=2\"",
  )
  |> should.be_true()

  string.contains(html, "value=\"abc&lt;def&gt;&amp;&quot;ghi&quot;\"")
  |> should.be_true()
}

pub fn build_response_form_post_invalid_url_test() {
  deep_linking.build_response_form_post("not-a-url", "jwt")
  |> should.equal(Error(errors.DeepLinkingResponseInvalidReturnUrl))
}

pub fn deep_linking_error_to_string_conversion_test() {
  errors.deep_linking_error_to_string(errors.DeepLinkingClaimMissing)
  |> should.equal("Missing required deep-linking claim.")
}

pub fn deep_linking_profile_error_to_string_conversion_test() {
  errors.deep_linking_error_to_string(errors.DeepLinkingProfileClaimInvalid(
    "aud",
  ))
  |> should.equal("Deep-linking profile output has invalid claim type: aud.")
}

fn decode_claim_string(claims, key: String) -> Result(String, String) {
  dict.get(claims, key)
  |> result.map_error(fn(_) { "missing" })
  |> result.try(fn(raw) {
    decode.run(raw, decode.string) |> result.map_error(fn(_) { "invalid" })
  })
}

fn dynamic_settings_claim() -> dynamic.Dynamic {
  dynamic.properties([
    #(
      dynamic.string("deep_link_return_url"),
      dynamic.string("https://platform.example.com/deep_link_return"),
    ),
    #(
      dynamic.string("accept_types"),
      dynamic.list([dynamic.string("ltiResourceLink"), dynamic.string("link")]),
    ),
    #(
      dynamic.string("accept_presentation_document_targets"),
      dynamic.list([dynamic.string("iframe")]),
    ),
    #(dynamic.string("accept_multiple"), dynamic.bool(True)),
    #(dynamic.string("accept_lineitem"), dynamic.bool(True)),
    #(dynamic.string("data"), dynamic.string("opaque-platform-data")),
  ])
}
