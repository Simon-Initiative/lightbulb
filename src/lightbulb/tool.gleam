import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/http/request
import gleam/http/response.{Response}
import gleam/httpc
import gleam/json
import gleam/list
import gleam/order.{Gt, Lt}
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import gleam/uri.{query_to_string}
import lightbulb/deep_linking
import lightbulb/deep_linking/settings
import lightbulb/errors.{
  type CoreError, AudienceInvalid, DeploymentNotFound, JwtExpired,
  JwtInvalidClaim, JwtInvalidSignature, JwtNotYetValid, LaunchMissingParam,
  LoginMissingParam, MessageTypeUnsupported, NonceInvalid, NonceValidationError,
  RegistrationNotFound, StateInvalid, StateNotFound, TargetLinkUriMismatch,
}
import lightbulb/jose.{type Claims, JoseJws, JoseJwt}
import lightbulb/providers/data_provider.{type DataProvider, LoginContext}
import lightbulb/registration.{type Registration}
import lightbulb/utils/logger
import youid/uuid

pub const deployment_id_claim = "https://purl.imsglobal.org/spec/lti/claim/deployment_id"

pub const message_type_claim = "https://purl.imsglobal.org/spec/lti/claim/message_type"

pub const version_claim = "https://purl.imsglobal.org/spec/lti/claim/version"

pub const target_link_uri_claim = "https://purl.imsglobal.org/spec/lti/claim/target_link_uri"

pub const resource_link_claim = "https://purl.imsglobal.org/spec/lti/claim/resource_link"

pub const roles_claim = "https://purl.imsglobal.org/spec/lti/claim/roles"

const lti_message_hint_claim = "lti_message_hint"

const login_context_ttl_minutes = 5

const timestamp_skew_seconds = 60

const inline_jwks_prefix = "inline_jwks:"

fn required_login_param(
  params: Dict(String, String),
  key: String,
) -> Result(String, CoreError) {
  dict.get(params, key)
  |> result.map_error(fn(_) { LoginMissingParam(key) })
}

fn required_launch_param(
  params: Dict(String, String),
  key: String,
) -> Result(String, CoreError) {
  dict.get(params, key)
  |> result.map_error(fn(_) { LaunchMissingParam(key) })
}

/// Builds an OIDC login response for the tool. This function will return a `state` and `redirect_url`.
/// The `state` is an opaque string that will be used to verify the response from the
/// OIDC provider. The `redirect_url` is the URL that the user will be redirected to
/// to authenticate and complete the OIDC login process.
/// (LTI 1.3 Specification)[https://www.imsglobal.org/spec/lti/v1p3#oidc-login-request] for more details.
pub fn oidc_login(
  provider: DataProvider,
  params: Dict(String, String),
) -> Result(#(String, String), CoreError) {
  use issuer <- result.try(required_login_param(params, "iss"))
  use target_link_uri <- result.try(required_login_param(
    params,
    "target_link_uri",
  ))
  use login_hint <- result.try(required_login_param(params, "login_hint"))
  use client_id <- result.try(required_login_param(params, "client_id"))

  use registration <- result.try(
    provider.get_registration(issuer, client_id)
    |> result.map_error(fn(_) { RegistrationNotFound }),
  )

  let state = uuid.v4_string()
  use nonce <- result.try(
    provider.create_nonce()
    |> result.map_error(fn(_) { NonceValidationError(NonceInvalid) }),
  )

  let login_context =
    LoginContext(
      state: state,
      target_link_uri: target_link_uri,
      issuer: issuer,
      client_id: client_id,
      expires_at: timestamp.system_time()
        |> timestamp.add(duration.minutes(login_context_ttl_minutes)),
    )

  use _ <- result.try(
    provider.save_login_context(login_context)
    |> result.map_error(fn(_) { StateInvalid }),
  )

  let query_params = [
    #("scope", "openid"),
    #("response_type", "id_token"),
    #("response_mode", "form_post"),
    #("prompt", "none"),
    #("client_id", client_id),
    #("redirect_uri", target_link_uri),
    #("state", state),
    #("nonce", nonce.nonce),
    #("login_hint", login_hint),
  ]

  let query_params = case dict.get(params, lti_message_hint_claim) {
    Ok(lti_message_hint) -> [
      #("lti_message_hint", lti_message_hint),
      ..query_params
    ]
    Error(_) -> query_params
  }

  let redirect_url =
    registration.auth_endpoint <> "?" <> query_to_string(query_params)

  Ok(#(state, redirect_url))
}

/// Validates the OIDC login response from the OIDC provider.
pub fn validate_launch(
  provider: DataProvider,
  params: Dict(String, String),
  session_state: String,
) -> Result(Claims, CoreError) {
  use id_token <- result.try(required_launch_param(params, "id_token"))
  use request_state <- result.try(required_launch_param(params, "state"))

  use <- bool.guard(
    when: request_state != session_state,
    return: Error(StateInvalid),
  )

  use registration <- result.try(peek_validate_registration(id_token, provider))
  use claims <- result.try(verify_token(id_token, registration.keyset_url))

  use _ <- result.try(validate_required_launch_claims(claims))
  use _ <- result.try(validate_deployment(
    claims,
    provider,
    registration.issuer,
    registration.client_id,
  ))
  use _ <- result.try(validate_timestamps(claims))
  use _ <- result.try(validate_nonce(claims, provider))
  use _ <- result.try(validate_login_context(
    claims,
    provider,
    request_state,
    registration,
  ))
  use _ <- result.try(
    provider.consume_login_context(request_state)
    |> result.map_error(fn(_) { StateNotFound }),
  )

  Ok(claims)
}

fn peek_validate_registration(
  id_token: String,
  provider: DataProvider,
) -> Result(Registration, CoreError) {
  let JoseJwt(claims: claims) = jose.peek(id_token)

  use issuer <- result.try(read_claim(claims, "iss", decode.string))
  use client_id <- result.try(resolve_client_id_from_claims(claims))

  provider.get_registration(issuer, client_id)
  |> result.map_error(fn(_) { RegistrationNotFound })
}

fn resolve_client_id_from_claims(claims: Claims) -> Result(String, CoreError) {
  use audience <- result.try(read_claim(claims, "aud", decode.dynamic))
  use audiences <- result.try(parse_audiences(audience))

  case audiences {
    [] -> Error(AudienceInvalid)
    [single] -> Ok(single)
    [_, _, ..] -> {
      use azp <- result.try(
        read_claim(claims, "azp", decode.string)
        |> result.map_error(fn(_) { AudienceInvalid }),
      )

      use <- bool.guard(
        when: !list.any(audiences, fn(client) { client == azp }),
        return: Error(AudienceInvalid),
      )

      Ok(azp)
    }
  }
}

fn parse_audiences(aud: Dynamic) -> Result(List(String), CoreError) {
  case decode.run(aud, decode.string) {
    Ok(single) -> Ok([single])

    Error(_) ->
      decode.run(aud, decode.list(decode.string))
      |> result.map_error(fn(_) { AudienceInvalid })
  }
}

fn read_claim(
  claims: Claims,
  claim: String,
  decoder: Decoder(a),
) -> Result(a, CoreError) {
  use value <- result.try(
    dict.get(claims, claim)
    |> result.map_error(fn(_) { JwtInvalidClaim }),
  )

  decode.run(value, decoder)
  |> result.map_error(fn(_) { JwtInvalidClaim })
}

fn peek_header_claim(
  jwt_string: String,
  header: String,
  decoder: Decoder(a),
) -> Result(a, CoreError) {
  case jose.peek_protected(jwt_string) {
    JoseJws(headers: headers, ..) -> {
      case dict.get(headers, header) {
        Ok(value) ->
          decode.run(value, decoder)
          |> result.map_error(fn(_) { JwtInvalidClaim })

        Error(_) -> Error(JwtInvalidClaim)
      }
    }
  }
}

fn verify_token(
  id_token: String,
  keyset_url: String,
) -> Result(Claims, CoreError) {
  use kid <- result.try(peek_header_claim(id_token, "kid", decode.string))
  use jwk <- result.try(fetch_jwk(keyset_url, kid))

  case jose.verify(jose.from_map(jwk), id_token) {
    #(True, JoseJwt(claims: claims), _) -> Ok(claims)

    _ -> {
      logger.error_meta("Failed to verify id_token", id_token)
      Error(JwtInvalidSignature)
    }
  }
}

fn fetch_jwk(
  keyset_url: String,
  kid: String,
) -> Result(Dict(String, String), CoreError) {
  case string.starts_with(keyset_url, inline_jwks_prefix) {
    True ->
      string.replace(keyset_url, inline_jwks_prefix, "")
      |> select_jwk_from_keyset(kid)

    False -> {
      use req <- result.try(
        request.to(keyset_url)
        |> result.map_error(fn(_) { JwtInvalidClaim }),
      )

      let req = request.prepend_header(req, "accept", "application/json")

      use resp <- result.try(
        httpc.send(req)
        |> result.map_error(fn(_) { JwtInvalidSignature }),
      )

      case resp {
        Response(status: 200, body: body, ..) ->
          select_jwk_from_keyset(body, kid)

        Response(status: status, ..) -> {
          logger.error_meta("Failed to fetch keyset", #(status, keyset_url))
          Error(JwtInvalidSignature)
        }
      }
    }
  }
}

fn select_jwk_from_keyset(
  body: String,
  kid: String,
) -> Result(Dict(String, String), CoreError) {
  let keyset_decoder = {
    use keys <- decode.field(
      "keys",
      decode.list(decode.dict(decode.string, decode.string)),
    )

    decode.success(keys)
  }

  case json.parse(from: body, using: keyset_decoder) {
    Ok(keys) ->
      list.find(keys, fn(key) { dict.get(key, "kid") == Ok(kid) })
      |> result.map_error(fn(_) { JwtInvalidSignature })

    Error(_) -> {
      logger.error_meta("Failed to parse keyset", body)
      Error(JwtInvalidClaim)
    }
  }
}

fn validate_required_launch_claims(claims: Claims) -> Result(String, CoreError) {
  use message_type <- result.try(read_claim(
    claims,
    message_type_claim,
    decode.string,
  ))

  case message_type {
    "LtiResourceLinkRequest" ->
      validate_resource_link_required_claims(claims)
      |> result.map(fn(_) { message_type })

    message if message == deep_linking.lti_message_type_deep_linking_request -> {
      settings.from_claims(claims)
      |> result.map_error(fn(_) { JwtInvalidClaim })
      |> result.map(fn(_) { message_type })
    }

    _ -> Error(MessageTypeUnsupported)
  }
}

fn validate_resource_link_required_claims(
  claims: Claims,
) -> Result(Claims, CoreError) {
  use version <- result.try(read_claim(claims, version_claim, decode.string))
  use <- bool.guard(when: version != "1.3.0", return: Error(JwtInvalidClaim))

  use _ <- result.try(read_claim(claims, deployment_id_claim, decode.string))
  use _ <- result.try(read_claim(claims, target_link_uri_claim, decode.string))
  use resource_link <- result.try(read_claim(
    claims,
    resource_link_claim,
    decode.dynamic,
  ))

  use _ <- result.try(
    decode.run(resource_link, {
      use resource_link_id <- decode.field("id", decode.string)
      decode.success(resource_link_id)
    })
    |> result.map_error(fn(_) { JwtInvalidClaim }),
  )

  use roles <- result.try(read_claim(
    claims,
    roles_claim,
    decode.list(decode.string),
  ))

  use <- bool.guard(when: roles == [], return: Error(JwtInvalidClaim))

  Ok(claims)
}

fn validate_deployment(
  claims: Claims,
  provider: DataProvider,
  issuer: String,
  client_id: String,
) -> Result(Claims, CoreError) {
  use deployment_id <- result.try(read_claim(
    claims,
    deployment_id_claim,
    decode.string,
  ))

  provider.get_deployment(issuer, client_id, deployment_id)
  |> result.map(fn(_) { claims })
  |> result.map_error(fn(_) { DeploymentNotFound })
}

fn validate_timestamps(claims: Claims) -> Result(Claims, CoreError) {
  use exp <- result.try(
    read_claim(claims, "exp", decode.int)
    |> result.map(timestamp.from_unix_seconds),
  )
  use iat <- result.try(
    read_claim(claims, "iat", decode.int)
    |> result.map(timestamp.from_unix_seconds),
  )

  let now = timestamp.system_time()
  let lower_bound =
    timestamp.add(now, duration.seconds(-timestamp_skew_seconds))
  let upper_bound = timestamp.add(now, duration.seconds(timestamp_skew_seconds))

  use <- bool.guard(
    when: timestamp.compare(exp, lower_bound) == Lt,
    return: Error(JwtExpired),
  )
  use <- bool.guard(
    when: timestamp.compare(iat, upper_bound) == Gt,
    return: Error(JwtInvalidClaim),
  )

  case dict.get(claims, "nbf") {
    Ok(nbf_dynamic) -> {
      use nbf <- result.try(
        decode.run(nbf_dynamic, decode.int)
        |> result.map(timestamp.from_unix_seconds)
        |> result.map_error(fn(_) { JwtInvalidClaim }),
      )

      use <- bool.guard(
        when: timestamp.compare(nbf, upper_bound) == Gt,
        return: Error(JwtNotYetValid),
      )

      Ok(claims)
    }

    Error(_) -> Ok(claims)
  }
}

fn validate_nonce(
  claims: Claims,
  provider: DataProvider,
) -> Result(Claims, CoreError) {
  use nonce <- result.try(read_claim(claims, "nonce", decode.string))

  provider.validate_nonce(nonce)
  |> result.map_error(fn(error) {
    logger.error_meta("Failed to validate nonce", #(error, nonce))
    NonceValidationError(error)
  })
  |> result.map(fn(_) { claims })
}

fn validate_login_context(
  claims: Claims,
  provider: DataProvider,
  request_state: String,
  registration: Registration,
) -> Result(Claims, CoreError) {
  use context <- result.try(
    provider.get_login_context(request_state)
    |> result.map_error(fn(_) { StateNotFound }),
  )

  let LoginContext(
    target_link_uri: stored_target_link_uri,
    issuer: issuer,
    client_id: client_id,
    expires_at: expires_at,
    ..,
  ) = context

  use <- bool.guard(
    when: timestamp.compare(expires_at, timestamp.system_time()) != Gt,
    return: Error(StateNotFound),
  )
  use <- bool.guard(
    when: issuer != registration.issuer || client_id != registration.client_id,
    return: Error(StateInvalid),
  )

  use target_link_uri <- result.try(read_claim(
    claims,
    target_link_uri_claim,
    decode.string,
  ))

  use <- bool.guard(
    when: target_link_uri != stored_target_link_uri,
    return: Error(TargetLinkUriMismatch),
  )

  Ok(claims)
}

/// Validates the LTI message type claim and required claims for that type.
pub fn validate_message_type(claims: Claims) -> Result(Claims, CoreError) {
  validate_required_launch_claims(claims)
  |> result.map(fn(_) { claims })
}
