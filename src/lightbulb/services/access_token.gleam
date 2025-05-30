import birl
import birl/duration
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import ids/uuid
import lightbulb/jose
import lightbulb/jwk.{type Jwk}
import lightbulb/providers.{type Providers}
import lightbulb/providers/http_provider.{type HttpProvider}
import lightbulb/registration.{type Registration}
import lightbulb/utils/logger

/// Represents an OAuth2 access token for LTI 1.3 services.
pub type AccessToken {
  AccessToken(token: String, token_type: String, expires_in: Int, scope: String)
}

/// Requests an OAuth2 access token. Returns Ok(AccessToken) on success, Error(_) otherwise.
///
/// As parameters, expects:
/// 1. `providers`: A `Providers` instance that contains the HTTP provider and data provider.
/// 2. `registration`: A `Registration` instance used to fetch the access token endpoint and client ID.
/// 3. `scopes`: A list of scopes to request for the access token.
///
/// Examples:
///
/// ```gleam
/// fetch_access_token(providers, registration, ["https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"])
/// // Ok(AccessToken("actual_access_token", "Bearer", 3600, "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"))
/// ```
pub fn fetch_access_token(
  providers: Providers,
  registration: Registration,
  scopes: List(String),
) -> Result(AccessToken, String) {
  use active_jwk <- result.try(providers.data.get_active_jwk())

  let client_assertion =
    create_client_assertion(
      active_jwk,
      registration.access_token_endpoint,
      registration.client_id,
      // TODO: should this be separate auth_server url for audience?
      Some(registration.access_token_endpoint),
    )

  request_token(
    providers.http,
    registration.access_token_endpoint,
    client_assertion,
    scopes,
  )
}

fn request_token(
  http_provider: HttpProvider,
  url: String,
  client_assertion: String,
  scopes: List(String),
) -> Result(AccessToken, String) {
  let body =
    uri.query_to_string([
      #("grant_type", "client_credentials"),
      #(
        "client_assertion_type",
        "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
      ),
      #("client_assertion", client_assertion),
      #("scope", string.join(scopes, " ")),
    ])

  use req <- result.try(
    request.to(url)
    |> result.replace_error("Error creating request for URL " <> url),
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
        200 | 201 -> decode_access_token(resp.body)
        _ -> {
          logger.error_meta("Error requesting access token", resp)

          Error("Error requesting access token")
        }
      }
    e -> {
      logger.error_meta("Error requesting access token", e)

      Error("Error requesting access token")
    }
  }
}

fn decode_access_token(body: String) -> Result(AccessToken, String) {
  let access_token_decoder = {
    use token <- decode.field("access_token", decode.string)
    use token_type <- decode.field("token_type", decode.string)
    use expires_in <- decode.field("expires_in", decode.int)
    use scope <- decode.field("scope", decode.string)

    decode.success(AccessToken(
      token: token,
      token_type: token_type,
      expires_in: expires_in,
      scope: scope,
    ))
  }

  json.parse(body, access_token_decoder)
  |> result.map_error(fn(e) {
    "Error decoding access token" <> string.inspect(e)
  })
}

fn create_client_assertion(
  active_jwk: Jwk,
  auth_token_url: String,
  client_id: String,
  auth_audience: Option(String),
) -> String {
  // let #(_, jwk) = jose.generate_key(jose.Rsa(2048)) |> jose.to_map()
  let #(_, jwk) = active_jwk |> jwk.to_map()

  let assert Ok(jti) = uuid.generate_v4()

  let jwt =
    dict.from_list([
      #("iss", dynamic.string(client_id)),
      #("aud", dynamic.string(audience(auth_token_url, auth_audience))),
      #("sub", dynamic.string(client_id)),
      #("iat", birl.now() |> birl.to_unix() |> dynamic.int()),
      #(
        "exp",
        birl.now()
          |> birl.add(duration.seconds(3600))
          |> birl.to_unix()
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

  let #(_, jose_jwt) = jose.sign_with_jws(jwk, jws, jwt)
  let #(_, compact_signed) = jose.compact(jose_jwt)

  compact_signed
}

fn audience(auth_token_url: String, auth_audience: Option(String)) -> String {
  case auth_audience {
    None -> auth_token_url
    Some("") -> auth_token_url
    Some(audience) -> audience
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
