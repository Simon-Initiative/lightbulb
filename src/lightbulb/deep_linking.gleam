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
  type DeepLinkingError,
  DeepLinkingClaimInvalid,
  DeepLinkingClaimMissing,
  DeepLinkingResponseInvalidReturnUrl,
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
  use _ <- result.try(validate_return_url(settings.deep_link_return_url))
  use _ <- result.try(content_item.validate_items(settings, items))
  use iss <- result.try(required_claim_string(request_claims, "iss"))
  use deployment_id <- result.try(required_claim_string(
    request_claims,
    claim_deployment_id,
  ))

  let base_claims =
    dict.from_list([
      #("aud", dynamic.string(iss)),
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

  let claims =
    base_claims
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
    |> maybe_add_optional(options.errorlog, claim_errorlog, dynamic.string)

  sign_claims(claims, active_jwk)
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
