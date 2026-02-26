import birl
import birl/duration
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
import gleam/uri.{query_to_string}
import lightbulb/deep_linking
import lightbulb/deep_linking/settings
import lightbulb/jose.{type Claims, JoseJws, JoseJwt}
import lightbulb/providers/data_provider.{
  type DataProvider,
  LoginContext,
}
import lightbulb/registration.{type Registration}
import lightbulb/utils/logger
import youid/uuid

const deployment_id_claim = "https://purl.imsglobal.org/spec/lti/claim/deployment_id"
const message_type_claim = "https://purl.imsglobal.org/spec/lti/claim/message_type"
const version_claim = "https://purl.imsglobal.org/spec/lti/claim/version"
const target_link_uri_claim = "https://purl.imsglobal.org/spec/lti/claim/target_link_uri"
const resource_link_claim = "https://purl.imsglobal.org/spec/lti/claim/resource_link"
const roles_claim = "https://purl.imsglobal.org/spec/lti/claim/roles"
const lti_message_hint_claim = "lti_message_hint"
const login_context_ttl_minutes = 5
const timestamp_skew_seconds = 60
const inline_jwks_prefix = "inline_jwks:"

fn error(code: String) -> String {
  code
}

fn error_detail(code: String, detail: String) -> String {
  code <> ":" <> detail
}

fn required_param(
  params: Dict(String, String),
  key: String,
  code: String,
) -> Result(String, String) {
  dict.get(params, key)
  |> result.replace_error(error_detail(code, key))
}

/// Builds an OIDC login response for the tool. This function will return a `state` and `redirect_url`.
/// The `state` is an opaque string that will be used to verify the response from the
/// OIDC provider. The `redirect_url` is the URL that the user will be redirected to
/// to authenticate and complete the OIDC login process.
/// (LTI 1.3 Specification)[https://www.imsglobal.org/spec/lti/v1p3#oidc-login-request] for more details.
pub fn oidc_login(
  provider: DataProvider,
  params: Dict(String, String),
) -> Result(#(String, String), String) {
  use issuer <- result.try(required_param(params, "iss", "core.login.missing_param"))
  use target_link_uri <- result.try(
    required_param(params, "target_link_uri", "core.login.missing_param"),
  )
  use login_hint <- result.try(
    required_param(params, "login_hint", "core.login.missing_param"),
  )
  use client_id <- result.try(
    required_param(params, "client_id", "core.login.missing_param"),
  )

  use registration <- result.try(
    provider.get_registration(issuer, client_id)
    |> result.replace_error(error("core.registration.not_found")),
  )

  let state = uuid.v4_string()
  use nonce <- result.try(
    provider.create_nonce()
    |> result.replace_error(error("core.nonce.invalid")),
  )

  let login_context =
    LoginContext(
      state: state,
      target_link_uri: target_link_uri,
      issuer: issuer,
      client_id: client_id,
      expires_at: birl.now() |> birl.add(duration.minutes(login_context_ttl_minutes)),
    )

  use _ <- result.try(
    provider.save_login_context(login_context)
    |> result.replace_error(error("core.state.invalid")),
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

  // pass back LTI message hint if given
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

/// Validates the OIDC login response from the OIDC provider. This function will validate and unpack
/// the `id_token` and return claims as a map if the token is valid. The `state` parametrer is the
/// opaque string that was stored in a cookie during `oidc_login` step.
pub fn validate_launch(
  provider: DataProvider,
  params: Dict(String, String),
  session_state: String,
) -> Result(Claims, String) {
  use id_token <- result.try(
    required_param(params, "id_token", "core.launch.missing_param"),
  )
  use request_state <- result.try(
    required_param(params, "state", "core.launch.missing_param"),
  )

  use <- bool.guard(
    when: request_state != session_state,
    return: Error(error("core.state.invalid")),
  )

  use registration <- result.try(peek_validate_registration(id_token, provider))
  use claims <- result.try(verify_token(id_token, registration.keyset_url))

  // Core validation matrix for resource link launches:
  // - message_type              -> validate_required_launch_claims
  // - version (1.3.0)           -> validate_resource_link_required_claims
  // - deployment_id             -> validate_resource_link_required_claims + validate_deployment
  // - target_link_uri           -> validate_resource_link_required_claims + validate_login_context
  // - resource_link.id          -> validate_resource_link_required_claims
  // - roles[]                   -> validate_resource_link_required_claims
  // - exp/iat(/nbf)             -> validate_timestamps
  // - nonce one-time + expiry   -> validate_nonce

  use _message_type <- result.try(validate_required_launch_claims(claims))
  use _claims <- result.try(validate_deployment(
    claims,
    provider,
    registration.issuer,
    registration.client_id,
  ))
  use _claims <- result.try(validate_timestamps(claims))
  use _claims <- result.try(validate_nonce(claims, provider))
  use _claims <- result.try(
    validate_login_context(claims, provider, request_state, registration),
  )
  use _ <- result.try(
    provider.consume_login_context(request_state)
    |> result.replace_error(error("core.state.not_found")),
  )

  Ok(claims)
}

fn peek_validate_registration(
  id_token: String,
  provider: DataProvider,
) -> Result(Registration, String) {
  let JoseJwt(claims: claims) = jose.peek(id_token)

  use issuer <- result.try(
    read_claim(claims, "iss", decode.string)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )
  use client_id <- result.try(resolve_client_id_from_claims(claims))

  provider.get_registration(issuer, client_id)
  |> result.replace_error(error("core.registration.not_found"))
}

fn resolve_client_id_from_claims(claims: Claims) -> Result(String, String) {
  use audience <- result.try(read_claim(claims, "aud", decode.dynamic))
  use audiences <- result.try(parse_audiences(audience))

  case audiences {
    [] -> Error(error("core.audience.invalid"))

    [single] -> Ok(single)

    [_, _, ..] -> {
      use azp <- result.try(
        read_claim(claims, "azp", decode.string)
        |> result.replace_error(error("core.audience.invalid")),
      )

      use <- bool.guard(
        when: !list.any(audiences, fn(audience_client_id) { audience_client_id == azp }),
        return: Error(error("core.audience.invalid")),
      )

      Ok(azp)
    }
  }
}

fn parse_audiences(aud: Dynamic) -> Result(List(String), String) {
  case decode.run(aud, decode.string) {
    Ok(single) -> Ok([single])

    Error(_) ->
      decode.run(aud, decode.list(decode.string))
      |> result.replace_error(error("core.audience.invalid"))
  }
}

fn read_claim(
  claims: Claims,
  claim: String,
  decoder: Decoder(a),
) -> Result(a, String) {
  use value <- result.try(dict.get(claims, claim) |> result.replace_error(claim))

  decode.run(value, decoder)
  |> result.replace_error(claim)
}

fn peek_header_claim(jwt_string, header: String, decoder: Decoder(a)) {
  case jose.peek_protected(jwt_string) {
    JoseJws(headers: headers, ..) -> {
      case dict.get(headers, header) {
        Ok(value) ->
          decode.run(value, decoder)
          |> result.replace_error(error("core.jwt.invalid_claim"))
        Error(_) -> Error(error("core.jwt.invalid_claim"))
      }
    }
  }
}

fn verify_token(id_token: String, keyset_url: String) {
  use kid <- result.try(
    peek_header_claim(id_token, "kid", decode.string)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )
  use jwk <- result.try(fetch_jwk(keyset_url, kid))

  case jose.verify(jose.from_map(jwk), id_token) {
    #(True, JoseJwt(claims: claims), _) -> Ok(claims)

    _ -> {
      logger.error_meta("Failed to verify id_token", id_token)
      Error(error("core.jwt.invalid_signature"))
    }
  }
}

fn fetch_jwk(keyset_url: String, kid: String) {
  case string.starts_with(keyset_url, inline_jwks_prefix) {
    True ->
      string.replace(keyset_url, inline_jwks_prefix, "")
      |> select_jwk_from_keyset(kid)

    False -> {
      use req <- result.try(
        request.to(keyset_url)
        |> result.replace_error(error("core.jwt.invalid_claim")),
      )

      let req = request.prepend_header(req, "accept", "application/json")

      use resp <- result.try(
        httpc.send(req)
        |> result.replace_error(error("core.jwt.invalid_signature")),
      )

      case resp {
        Response(status: 200, body: body, ..) -> select_jwk_from_keyset(body, kid)

        Response(status: status, ..) -> {
          logger.error_meta("Failed to fetch keyset", #(status, keyset_url))
          Error(error("core.jwt.invalid_signature"))
        }
      }
    }
  }
}

fn select_jwk_from_keyset(body: String, kid: String) {
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
      |> result.replace_error(error("core.jwt.invalid_signature"))

    Error(_) -> {
      logger.error_meta("Failed to parse keyset", body)
      Error(error("core.jwt.invalid_claim"))
    }
  }
}

fn validate_required_launch_claims(claims: Claims) -> Result(String, String) {
  use message_type <- result.try(
    read_claim(claims, message_type_claim, decode.string)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )

  case message_type {
    "LtiResourceLinkRequest" ->
      validate_resource_link_required_claims(claims)
      |> result.map(fn(_) { message_type })

    message
      if message == deep_linking.lti_message_type_deep_linking_request
    -> {
      settings.from_claims(claims)
      |> result.replace_error(error("core.jwt.invalid_claim"))
      |> result.map(fn(_) { message_type })
    }

    _ -> Error(error("core.message_type.unsupported"))
  }
}

fn validate_resource_link_required_claims(claims: Claims) {
  use version <- result.try(
    read_claim(claims, version_claim, decode.string)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )
  use <- bool.guard(
    when: version != "1.3.0",
    return: Error(error("core.jwt.invalid_claim")),
  )

  use _deployment_id <- result.try(
    read_claim(claims, deployment_id_claim, decode.string)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )
  use _target_link_uri <- result.try(
    read_claim(claims, target_link_uri_claim, decode.string)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )
  use resource_link <- result.try(
    read_claim(claims, resource_link_claim, decode.dynamic)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )

  use _resource_link_id <- result.try(
    decode.run(resource_link, {
      use resource_link_id <- decode.field("id", decode.string)
      decode.success(resource_link_id)
    })
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )

  use roles <- result.try(
    read_claim(claims, roles_claim, decode.list(decode.string))
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )

  use <- bool.guard(
    when: roles == [],
    return: Error(error("core.jwt.invalid_claim")),
  )

  Ok(claims)
}

fn validate_deployment(
  claims: Claims,
  provider: DataProvider,
  issuer: String,
  client_id: String,
) {
  use deployment_id <- result.try(
    read_claim(claims, deployment_id_claim, decode.string)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )

  provider.get_deployment(issuer, client_id, deployment_id)
  |> result.map(fn(_) { claims })
  |> result.replace_error(error("core.deployment.not_found"))
}

fn validate_timestamps(claims: Claims) {
  use exp <- result.try(
    read_claim(claims, "exp", decode.int)
    |> result.map(birl.from_unix)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )
  use iat <- result.try(
    read_claim(claims, "iat", decode.int)
    |> result.map(birl.from_unix)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )

  let now = birl.now()
  let skew = duration.seconds(timestamp_skew_seconds)
  let lower_bound = birl.subtract(now, skew)
  let upper_bound = birl.add(now, skew)

  use <- bool.guard(
    when: birl.compare(exp, lower_bound) == Lt,
    return: Error(error("core.jwt.expired")),
  )
  use <- bool.guard(
    when: birl.compare(iat, upper_bound) == Gt,
    return: Error(error("core.jwt.invalid_claim")),
  )

  case dict.get(claims, "nbf") {
    Ok(nbf_dynamic) -> {
      use nbf <- result.try(
        decode.run(nbf_dynamic, decode.int)
        |> result.map(birl.from_unix)
        |> result.replace_error(error("core.jwt.invalid_claim")),
      )

      use <- bool.guard(
        when: birl.compare(nbf, upper_bound) == Gt,
        return: Error(error("core.jwt.not_yet_valid")),
      )

      Ok(claims)
    }

    Error(_) -> Ok(claims)
  }
}

fn validate_nonce(claims: Claims, provider: DataProvider) {
  use nonce <- result.try(
    read_claim(claims, "nonce", decode.string)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )

  provider.validate_nonce(nonce)
  |> result.map_error(fn(code) {
    logger.error_meta("Failed to validate nonce", #(code, nonce))
    code
  })
  |> result.map(fn(_) { claims })
}

fn validate_login_context(
  claims: Claims,
  provider: DataProvider,
  request_state: String,
  registration: Registration,
) {
  use context <- result.try(
    provider.get_login_context(request_state)
    |> result.replace_error(error("core.state.not_found")),
  )

  let LoginContext(
    target_link_uri: stored_target_link_uri,
    issuer: issuer,
    client_id: client_id,
    expires_at: expires_at,
    ..
  ) = context

  use <- bool.guard(
    when: birl.compare(expires_at, birl.now()) != Gt,
    return: Error(error("core.state.not_found")),
  )
  use <- bool.guard(
    when: issuer != registration.issuer || client_id != registration.client_id,
    return: Error(error("core.state.invalid")),
  )

  use target_link_uri <- result.try(
    read_claim(claims, target_link_uri_claim, decode.string)
    |> result.replace_error(error("core.jwt.invalid_claim")),
  )

  use <- bool.guard(
    when: target_link_uri != stored_target_link_uri,
    return: Error(error("core.target_link_uri.mismatch")),
  )

  Ok(claims)
}

/// Validates the LTI launch message type and dispatches to the corresponding
/// message-specific validator.
pub fn validate_message_type(claims: Claims) {
  validate_required_launch_claims(claims)
  |> result.map(fn(_) { claims })
}
