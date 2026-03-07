//// # Deep Linking
////
//// Deep Linking 2.0 helpers for decoding settings and building response JWTs.
////
//// ## Example
////
//// ```gleam
//// import gleam/http/response
//// import gleam/option
//// import gleam/result
//// import lightbulb/deep_linking
//// import lightbulb/deep_linking/content_item
//// import lightbulb/errors
//// import wisp.{type Request, type Response}
////
//// pub fn deep_linking_response(
////   _req: Request,
////   data_provider,
////   claims,
//// ) -> Response {
////   case build_deep_linking_response_html(data_provider, claims) {
////     Ok(html) ->
////       wisp.ok()
////       |> response.set_header("content-type", "text/html; charset=utf-8")
////       |> wisp.string_body(html)
////
////     Error(error) ->
////       wisp.bad_request()
////       |> wisp.string_body(
////         "Deep linking response failed: "
////         <> errors.deep_linking_error_to_string(error),
////       )
////   }
//// }
////
//// fn build_deep_linking_response_html(data_provider, claims) {
////   use settings <- result.try(deep_linking.get_deep_linking_settings(claims))
////   use active_jwk <- result.try(data_provider.get_active_jwk())
////
////   let items = [
////     content_item.lti_resource_link(
////       option.Some("https://tool.example.com/launch/resource-1"),
////       option.Some("Resource 1"),
////       option.None,
////       option.None,
////       option.None,
////     ),
////   ]
////
////   use jwt <- result.try(
////     deep_linking.build_response_jwt(
////       request_claims: claims,
////       settings: settings,
////       items: items,
////       options: deep_linking.default_response_options(),
////       active_jwk: active_jwk,
////     ),
////   )
////
////   deep_linking.build_response_form_post(settings.deep_link_return_url, jwt)
//// }
//// ```

import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import gleam/uri
import lightbulb/deep_linking/content_item.{type ContentItem}
import lightbulb/deep_linking/settings.{type DeepLinkingSettings}
import lightbulb/errors.{
  type DeepLinkingError, DeepLinkingClaimInvalid, DeepLinkingClaimMissing,
  DeepLinkingProfileClaimInvalid, DeepLinkingProfileClaimMissing,
  DeepLinkingProfileInvalid, DeepLinkingResponseInvalidReturnUrl,
  DeepLinkingResponseSigningFailed,
}
import lightbulb/jose
import lightbulb/jwk.{type Jwk}

pub const lti_message_type_deep_linking_request = "LtiDeepLinkingRequest"

pub const lti_message_type_deep_linking_response = "LtiDeepLinkingResponse"

pub const lti_version = "1.3.0"

pub const claim_message_type = "https://purl.imsglobal.org/spec/lti/claim/message_type"

pub const claim_version = "https://purl.imsglobal.org/spec/lti/claim/version"

pub const claim_deployment_id = "https://purl.imsglobal.org/spec/lti/claim/deployment_id"

pub const claim_data = "https://purl.imsglobal.org/spec/lti-dl/claim/data"

pub const claim_content_items = "https://purl.imsglobal.org/spec/lti-dl/claim/content_items"

pub const claim_msg = "https://purl.imsglobal.org/spec/lti-dl/claim/msg"

pub const claim_log = "https://purl.imsglobal.org/spec/lti-dl/claim/log"

pub const claim_errormsg = "https://purl.imsglobal.org/spec/lti-dl/claim/errormsg"

pub const claim_errorlog = "https://purl.imsglobal.org/spec/lti-dl/claim/errorlog"

pub type DeepLinkingResponseOptions {
  DeepLinkingResponseOptions(
    msg: Option(String),
    log: Option(String),
    errormsg: Option(String),
    errorlog: Option(String),
    ttl_seconds: Int,
  )
}

pub type ResponseJwtContext {
  ResponseJwtContext(
    request_claims: jose.Claims,
    settings: DeepLinkingSettings,
    items: List(ContentItem),
    options: DeepLinkingResponseOptions,
  )
}

pub type ClaimTransform =
  fn(jose.Claims, ResponseJwtContext) -> Result(jose.Claims, DeepLinkingError)

pub type ResponseJwtProfile {
  Standard
  Canvas
  Custom(transform: ClaimTransform)
}

/// Returns default options for deep-linking responses.
///
/// Defaults:
/// - no optional message/log/error fields
/// - `ttl_seconds = 300`
pub fn default_response_options() -> DeepLinkingResponseOptions {
  DeepLinkingResponseOptions(
    msg: option.None,
    log: option.None,
    errormsg: option.None,
    errorlog: option.None,
    ttl_seconds: 300,
  )
}

fn unix_seconds(value: timestamp.Timestamp) -> Int {
  timestamp.to_unix_seconds_and_nanoseconds(value).0
}

/// Decodes deep-linking settings from validated launch claims.
///
/// Returns:
/// - `Ok(DeepLinkingSettings)` when the claim is present and valid
/// - `Error(DeepLinkingClaimMissing)` when the settings claim is absent
/// - `Error(DeepLinkingSettingsInvalid)` when the claim shape is invalid
pub fn get_deep_linking_settings(
  claims: jose.Claims,
) -> Result(DeepLinkingSettings, DeepLinkingError) {
  settings.from_claims(claims)
}

/// Builds and signs a Deep Linking response JWT.
///
/// This function validates return URL and content items, enforces required response
/// claims, conditionally echoes request `data`, and signs with RS256 using the
/// provided active JWK.
pub fn build_response_jwt(
  request_claims: jose.Claims,
  settings: DeepLinkingSettings,
  items: List(ContentItem),
  options: DeepLinkingResponseOptions,
  active_jwk: Jwk,
) -> Result(String, DeepLinkingError) {
  build_response_jwt_with_profile(
    request_claims,
    settings,
    items,
    options,
    active_jwk,
    Standard,
  )
}

/// Builds and signs a Deep Linking response JWT with a claim-shaping profile.
///
/// Profiles:
/// - `Standard`: current/default claim shape.
/// - `Canvas`: Canvas-compatible identity claim shape.
/// - `Custom`: caller-provided transform over standard claims.
pub fn build_response_jwt_with_profile(
  request_claims: jose.Claims,
  settings: DeepLinkingSettings,
  items: List(ContentItem),
  options: DeepLinkingResponseOptions,
  active_jwk: Jwk,
  profile: ResponseJwtProfile,
) -> Result(String, DeepLinkingError) {
  use _ <- result.try(validate_return_url(settings.deep_link_return_url))
  use _ <- result.try(content_item.validate_items(settings, items))
  use base_claims <- result.try(build_standard_response_claims(
    request_claims,
    settings,
    items,
    options,
  ))
  let context = ResponseJwtContext(request_claims, settings, items, options)
  use transformed_claims <- result.try(apply_profile_transform(
    base_claims,
    context,
    profile,
  ))
  use _ <- result.try(validate_final_response_claims(
    transformed_claims,
    profile,
  ))

  sign_claims(transformed_claims, active_jwk)
}

/// Builds an auto-submit HTML form that POSTs the response JWT to the platform.
///
/// The form posts the token under the required parameter name: `JWT`.
pub fn build_response_form_post(
  deep_link_return_url: String,
  jwt: String,
) -> Result(String, DeepLinkingError) {
  use _ <- result.try(validate_return_url(deep_link_return_url))

  Ok(
    "<!doctype html><html><body>"
    <> "<form id=\"deep-linking-form\" action=\""
    <> escape_html_attribute(deep_link_return_url)
    <> "\" method=\"POST\">"
    <> "<input type=\"hidden\" name=\"JWT\" value=\""
    <> escape_html_attribute(jwt)
    <> "\"/>"
    <> "</form>"
    <> "<script>document.getElementById('deep-linking-form').submit();</script>"
    <> "</body></html>",
  )
}

fn validate_return_url(url: String) -> Result(Nil, DeepLinkingError) {
  case uri.parse(url) {
    Ok(parsed) -> {
      case parsed.scheme {
        option.Some("http") | option.Some("https") -> Ok(Nil)
        _ -> Error(DeepLinkingResponseInvalidReturnUrl)
      }
    }
    Error(_) -> Error(DeepLinkingResponseInvalidReturnUrl)
  }
}

fn build_standard_response_claims(
  request_claims request_claims: jose.Claims,
  settings settings: DeepLinkingSettings,
  items items: List(ContentItem),
  options options: DeepLinkingResponseOptions,
) -> Result(jose.Claims, DeepLinkingError) {
  use platform_issuer <- result.try(required_claim_string(request_claims, "iss"))
  use deployment_id <- result.try(required_claim_string(
    request_claims,
    claim_deployment_id,
  ))

  Ok(
    dict.from_list([
      #("aud", dynamic.string(platform_issuer)),
      #(
        claim_message_type,
        dynamic.string(lti_message_type_deep_linking_response),
      ),
      #(claim_version, dynamic.string(lti_version)),
      #(claim_deployment_id, dynamic.string(deployment_id)),
      #(
        "iat",
        timestamp.system_time()
          |> unix_seconds
          |> dynamic.int,
      ),
      #(
        "exp",
        timestamp.system_time()
          |> timestamp.add(duration.seconds(options.ttl_seconds))
          |> unix_seconds
          |> dynamic.int(),
      ),
    ])
    |> maybe_add_optional(settings.data, claim_data, dynamic.string)
    |> maybe_add_optional(
      case items != [] {
        True ->
          option.Some(dynamic.list(list.map(items, content_item.to_dynamic)))
        False -> option.None
      },
      claim_content_items,
      fn(value) { value },
    )
    |> maybe_add_optional(options.msg, claim_msg, dynamic.string)
    |> maybe_add_optional(options.log, claim_log, dynamic.string)
    |> maybe_add_optional(options.errormsg, claim_errormsg, dynamic.string)
    |> maybe_add_optional(options.errorlog, claim_errorlog, dynamic.string),
  )
}

fn apply_profile_transform(
  base_claims: jose.Claims,
  context: ResponseJwtContext,
  profile: ResponseJwtProfile,
) -> Result(jose.Claims, DeepLinkingError) {
  case profile {
    Standard -> Ok(base_claims)
    Canvas -> apply_canvas_transform(base_claims, context.request_claims)
    Custom(transform) ->
      transform(base_claims, context)
      |> result.map_error(normalize_custom_profile_error)
  }
}

fn apply_canvas_transform(
  base_claims: jose.Claims,
  request_claims: jose.Claims,
) -> Result(jose.Claims, DeepLinkingError) {
  use platform_issuer <- result.try(required_profile_claim_string(
    request_claims,
    "iss",
  ))
  use client_id <- result.try(resolve_request_client_id(request_claims))

  Ok(
    base_claims
    |> dict.insert("iss", dynamic.string(client_id))
    |> dict.insert("sub", dynamic.string(client_id))
    |> dict.insert("aud", dynamic.string(platform_issuer))
    |> dict.insert("azp", dynamic.string(client_id)),
  )
}

fn resolve_request_client_id(
  request_claims: jose.Claims,
) -> Result(String, DeepLinkingError) {
  use raw_aud <- result.try(
    dict.get(request_claims, "aud")
    |> result.map_error(fn(_) { DeepLinkingProfileClaimMissing("aud") }),
  )

  case decode.run(raw_aud, decode.string) {
    Ok(single) -> Ok(single)
    Error(_) -> {
      case decode.run(raw_aud, decode.list(decode.string)) {
        Ok([first, ..]) -> Ok(first)
        Ok([]) -> Error(DeepLinkingProfileClaimInvalid("aud"))
        Error(_) -> Error(DeepLinkingProfileClaimInvalid("aud"))
      }
    }
  }
}

fn normalize_custom_profile_error(error: DeepLinkingError) -> DeepLinkingError {
  case error {
    DeepLinkingProfileInvalid
    | DeepLinkingProfileClaimMissing(_)
    | DeepLinkingProfileClaimInvalid(_) -> error
    _ -> DeepLinkingProfileInvalid
  }
}

fn validate_final_response_claims(
  claims: jose.Claims,
  profile: ResponseJwtProfile,
) -> Result(Nil, DeepLinkingError) {
  use _ <- result.try(
    validate_required_string_claims(claims, [
      "aud",
      claim_message_type,
      claim_version,
      claim_deployment_id,
    ]),
  )
  use _ <- result.try(validate_required_int_claims(claims, ["iat", "exp"]))

  case profile {
    Canvas -> validate_required_string_claims(claims, ["iss", "sub", "azp"])
    _ -> Ok(Nil)
  }
}

fn validate_required_string_claims(
  claims: jose.Claims,
  claim_names: List(String),
) -> Result(Nil, DeepLinkingError) {
  list.fold(claim_names, Ok(Nil), fn(acc, claim_name) {
    use _ <- result.try(acc)
    use _ <- result.try(required_profile_claim_string(claims, claim_name))
    Ok(Nil)
  })
}

fn validate_required_int_claims(
  claims: jose.Claims,
  claim_names: List(String),
) -> Result(Nil, DeepLinkingError) {
  list.fold(claim_names, Ok(Nil), fn(acc, claim_name) {
    use _ <- result.try(acc)
    use _ <- result.try(required_profile_claim_int(claims, claim_name))
    Ok(Nil)
  })
}

fn sign_claims(
  claims: dict.Dict(String, dynamic.Dynamic),
  active_jwk: Jwk,
) -> Result(String, DeepLinkingError) {
  let #(_, jwk_map) = jwk.to_map(active_jwk)
  let jws =
    dict.from_list([
      #("alg", "RS256"),
      #("typ", "JWT"),
      #("kid", active_jwk.kid),
    ])

  let #(_, jose_jwt) = jose.sign_with_jws(jwk_map, jws, claims)
  let #(_, compact_signed) = jose.compact(jose_jwt)

  case string.is_empty(compact_signed) {
    True -> Error(DeepLinkingResponseSigningFailed)
    False -> Ok(compact_signed)
  }
}

fn required_claim_string(
  claims: jose.Claims,
  claim_name: String,
) -> Result(String, DeepLinkingError) {
  dict.get(claims, claim_name)
  |> result.map_error(fn(_) { DeepLinkingClaimMissing })
  |> result.try(fn(raw) {
    decode.run(raw, decode.string)
    |> result.map_error(fn(_) { DeepLinkingClaimInvalid })
  })
}

fn required_profile_claim_string(
  claims: jose.Claims,
  claim_name: String,
) -> Result(String, DeepLinkingError) {
  use raw <- result.try(
    dict.get(claims, claim_name)
    |> result.map_error(fn(_) { DeepLinkingProfileClaimMissing(claim_name) }),
  )

  decode.run(raw, decode.string)
  |> result.map_error(fn(_) { DeepLinkingProfileClaimInvalid(claim_name) })
}

fn required_profile_claim_int(
  claims: jose.Claims,
  claim_name: String,
) -> Result(Int, DeepLinkingError) {
  use raw <- result.try(
    dict.get(claims, claim_name)
    |> result.map_error(fn(_) { DeepLinkingProfileClaimMissing(claim_name) }),
  )

  decode.run(raw, decode.int)
  |> result.map_error(fn(_) { DeepLinkingProfileClaimInvalid(claim_name) })
}

fn maybe_add_optional(
  claims: dict.Dict(String, dynamic.Dynamic),
  value: Option(a),
  key: String,
  encoder: fn(a) -> dynamic.Dynamic,
) {
  case value {
    option.Some(value) -> dict.insert(claims, key, encoder(value))
    option.None -> claims
  }
}

fn escape_html_attribute(value: String) -> String {
  value
  |> string.replace("&", "&amp;")
  |> string.replace("\"", "&quot;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
}
