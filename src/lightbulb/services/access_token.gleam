//// # Access Token Service
////
//// OAuth2 client-credentials helpers for obtaining LTI service access tokens.
////
//// ## Example
////
//// ```gleam
//// import gleam/result
//// import lightbulb/services/access_token
//// import lightbulb/services/access_token_cache
////
//// fn fetch_ags_token(
////   cache: access_token_cache.TokenCache,
////   providers,
////   registration,
//// ) {
////   let scopes = [
////     "https://purl.imsglobal.org/spec/lti-ags/scope/score",
////   ]
////
////   // Cached flow:
////   use #(token, updated_cache) <- result.try(
////     access_token_cache.fetch_access_token_with_cache(
////       cache,
////       providers,
////       registration,
////       scopes,
////     ),
////   )
////
////   // Direct flow (without cache):
////   // use token <- result.try(
////   //   access_token.fetch_access_token(providers, registration, scopes)
////   // )
////
////   Ok(#(token, updated_cache))
//// }
//// ```
import gleam/bool
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import gleam/uri
import lightbulb/jose
import lightbulb/jwk.{type Jwk}
import lightbulb/providers.{type Providers}
import lightbulb/providers/data_provider
import lightbulb/providers/http_provider.{type HttpProvider}
import lightbulb/registration.{type Registration}
import lightbulb/utils/logger
import youid/uuid

const default_assertion_lifetime_seconds = 300

/// Represents an OAuth2 access token for LTI 1.3 services.
pub type AccessToken {
  AccessToken(token: String, token_type: String, expires_in: Int, scope: String)
}

pub type AccessTokenError {
  RequestBuildError(reason: String)
  HttpTransportError(reason: String)
  HttpStatusError(status: Int, body: String)
  OAuthError(
    error: String,
    error_description: Option(String),
    error_uri: Option(String),
  )
  DecodeError(reason: String)
  AssertionBuildError(reason: String)
}

pub type AssertionOptions {
  AssertionOptions(audience: Option(String), lifetime_seconds: Int)
}

/// Returns default client-assertion options.
pub fn default_assertion_options() -> AssertionOptions {
  AssertionOptions(
    audience: None,
    lifetime_seconds: default_assertion_lifetime_seconds,
  )
}

fn unix_seconds(value: timestamp.Timestamp) -> Int {
  timestamp.to_unix_seconds_and_nanoseconds(value).0
}

/// Converts access-token errors to stable human-readable messages.
pub fn access_token_error_to_string(error: AccessTokenError) -> String {
  case error {
    RequestBuildError(reason) -> "OAuth request build failed: " <> reason
    HttpTransportError(reason) -> "OAuth request transport failed: " <> reason
    HttpStatusError(status, _) ->
      "OAuth token endpoint returned unexpected status: "
      <> int.to_string(status)
    OAuthError(error, error_description, _) ->
      case error_description {
        Some(description) ->
          "OAuth token endpoint error (" <> error <> "): " <> description
        None -> "OAuth token endpoint error: " <> error
      }
    DecodeError(reason) -> "OAuth token response decode failed: " <> reason
    AssertionBuildError(reason) ->
      "OAuth client assertion build failed: " <> reason
  }
}

/// Requests an OAuth2 access token.
pub fn fetch_access_token(
  providers: Providers,
  registration: Registration,
  scopes: List(String),
) -> Result(AccessToken, AccessTokenError) {
  fetch_access_token_with_options(
    providers,
    registration,
    scopes,
    default_assertion_options(),
  )
}

/// Requests an OAuth2 access token using assertion options for audience and JWT lifetime.
pub fn fetch_access_token_with_options(
  providers: Providers,
  registration: Registration,
  scopes: List(String),
  assertion_options: AssertionOptions,
) -> Result(AccessToken, AccessTokenError) {
  use active_jwk <- result.try(
    providers.data.get_active_jwk()
    |> result.map_error(fn(error) {
      AssertionBuildError(data_provider.provider_error_to_string(error))
    }),
  )

  let AssertionOptions(audience: configured_audience, ..) = assertion_options
  let resolved_audience =
    audience(registration.access_token_endpoint, configured_audience)

  use client_assertion <- result.try(build_client_assertion(
    active_jwk,
    resolved_audience,
    registration.client_id,
    assertion_options,
  ))

  request_token(
    providers.http,
    registration.access_token_endpoint,
    client_assertion,
    scopes,
  )
}

/// Builds and signs an OAuth client assertion JWT using the active JWK.
pub fn build_client_assertion(
  active_jwk: Jwk,
  assertion_audience: String,
  client_id: String,
  options: AssertionOptions,
) -> Result(String, AccessTokenError) {
  use <- bool.guard(
    when: string.trim(client_id) == "",
    return: Error(AssertionBuildError("client_id is required")),
  )

  use <- bool.guard(
    when: string.trim(active_jwk.kid) == "",
    return: Error(AssertionBuildError("active JWK is missing kid")),
  )

  let AssertionOptions(lifetime_seconds: lifetime_seconds, ..) = options
  use <- bool.guard(
    when: lifetime_seconds <= 0,
    return: Error(AssertionBuildError(
      "assertion lifetime must be greater than zero",
    )),
  )

  let #(_, jwk_map) = jwk.to_map(active_jwk)
  let jti = uuid.v4_string()
  let now = timestamp.system_time() |> unix_seconds

  let jwt =
    dict.from_list([
      #("iss", dynamic.string(client_id)),
      #("aud", dynamic.string(assertion_audience)),
      #("sub", dynamic.string(client_id)),
      #("iat", dynamic.int(now)),
      #(
        "exp",
        timestamp.system_time()
          |> timestamp.add(duration.seconds(lifetime_seconds))
          |> unix_seconds
          |> dynamic.int(),
      ),
      #("jti", dynamic.string(jti)),
    ])

  let jws =
    dict.from_list([
      #("alg", "RS256"),
      #("typ", "JWT"),
      #("kid", active_jwk.kid),
    ])

  let #(_, jose_jwt) = jose.sign_with_jws(jwk_map, jws, jwt)
  let #(_, compact_signed) = jose.compact(jose_jwt)

  Ok(compact_signed)
}

fn request_token(
  http_provider: HttpProvider,
  url: String,
  client_assertion: String,
  scopes: List(String),
) -> Result(AccessToken, AccessTokenError) {
  let requested_scope = string.join(scopes, " ")

  let body =
    uri.query_to_string([
      #("grant_type", "client_credentials"),
      #(
        "client_assertion_type",
        "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      ),
      #("client_assertion", client_assertion),
      #("scope", requested_scope),
    ])

  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) {
      RequestBuildError("invalid token endpoint URL: " <> url)
    }),
  )

  let req =
    req
    |> request.set_header("Content-Type", "application/x-www-form-urlencoded")
    |> request.set_header("Accept", "application/json")
    |> request.set_method(http.Post)
    |> request.set_body(body)

  case http_provider.send(req) {
    Ok(resp) ->
      case resp.status {
        200 | 201 -> decode_access_token(resp.body, requested_scope)
        _ -> {
          logger.error_meta("Error requesting access token", resp)
          decode_oauth_error(resp.status, resp.body)
        }
      }

    Error(reason) -> {
      logger.error_meta("Error requesting access token", reason)
      Error(HttpTransportError(string.inspect(reason)))
    }
  }
}

fn decode_access_token(
  body: String,
  requested_scope: String,
) -> Result(AccessToken, AccessTokenError) {
  let access_token_decoder = {
    use token <- decode.field("access_token", decode.string)
    use token_type <- decode.field("token_type", decode.string)
    use expires_in <- decode.optional_field(
      "expires_in",
      None,
      decode.optional(decode.int),
    )
    use scope <- decode.optional_field(
      "scope",
      None,
      decode.optional(decode.string),
    )

    decode.success(
      AccessToken(
        token: token,
        token_type: token_type,
        expires_in: case expires_in {
          Some(value) -> value
          None -> 0
        },
        scope: case scope {
          Some(value) -> value
          None -> requested_scope
        },
      ),
    )
  }

  json.parse(body, access_token_decoder)
  |> result.map_error(fn(e) {
    DecodeError("invalid token response body: " <> string.inspect(e))
  })
}

fn decode_oauth_error(status: Int, body: String) -> Result(a, AccessTokenError) {
  let oauth_error_decoder = {
    use error <- decode.field("error", decode.string)
    use error_description <- decode.optional_field(
      "error_description",
      None,
      decode.optional(decode.string),
    )
    use error_uri <- decode.optional_field(
      "error_uri",
      None,
      decode.optional(decode.string),
    )

    decode.success(#(error, error_description, error_uri))
  }

  case json.parse(body, oauth_error_decoder) {
    Ok(#(error, description, error_uri)) ->
      Error(OAuthError(error, description, error_uri))
    Error(_) -> Error(HttpStatusError(status, body))
  }
}

fn audience(auth_token_url: String, auth_audience: Option(String)) -> String {
  case auth_audience {
    None -> auth_token_url
    Some("") -> auth_token_url
    Some(audience_value) -> audience_value
  }
}

/// Sets the Authorization header for a request using the provided access token.
pub fn set_authorization_header(
  req: Request(String),
  access_token: AccessToken,
) -> Request(String) {
  let AccessToken(token: token, ..) = access_token

  req
  |> request.set_header("Authorization", "Bearer " <> token)
}
