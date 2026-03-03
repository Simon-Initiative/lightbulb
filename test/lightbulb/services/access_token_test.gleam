import gleam/dict
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleeunit/should
import lightbulb/jose
import lightbulb/jwk
import lightbulb/providers
import lightbulb/providers/http_mock_provider
import lightbulb/providers/memory_provider
import lightbulb/registration.{type Registration, Registration}
import lightbulb/services/access_token.{
  AccessToken, AssertionBuildError, AssertionOptions, HttpStatusError,
  OAuthError, access_token_error_to_string, build_client_assertion,
  fetch_access_token,
}
import lightbulb/services/ags
import lightbulb/services/nrps

type Fixture {
  Fixture(
    memory: memory_provider.MemoryProvider,
    providers: providers.Providers,
    registration: Registration,
    scopes: List(String),
    active_jwk: jwk.Jwk,
  )
}

pub fn access_token_success_and_request_shape_test() {
  let fixture =
    setup_fixture(fn(req) {
      req.path
      |> should.equal("/auth/token")

      req.method
      |> should.equal(http.Post)

      req
      |> request.get_header("content-type")
      |> should.equal(Ok("application/x-www-form-urlencoded"))

      req
      |> request.get_header("accept")
      |> should.equal(Ok("application/json"))

      req.body
      |> string.contains("grant_type=client_credentials")
      |> should.equal(True)

      req.body
      |> string.contains(
        "client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer",
      )
      |> should.equal(True)

      req.body
      |> string.contains("scope=")
      |> should.equal(True)

      req.body
      |> string.contains("client_assertion=")
      |> should.equal(True)

      response.new(200)
      |> response.set_body(
        "\n        {\n          \"access_token\": \"SOME_ACCESS_TOKEN\",\n          \"token_type\": \"Bearer\",\n          \"expires_in\": 3600,\n          \"scope\": \"some scopes\"\n        }\n        ",
      )
      |> Ok
    })

  fetch_access_token(fixture.providers, fixture.registration, fixture.scopes)
  |> should.equal(
    Ok(AccessToken("SOME_ACCESS_TOKEN", "Bearer", 3600, "some scopes")),
  )

  memory_provider.cleanup(fixture.memory)
}

pub fn tolerant_decode_missing_optional_fields_test() {
  let fixture =
    setup_fixture(fn(_req) {
      response.new(200)
      |> response.set_body(
        "{\"access_token\":\"SOME_ACCESS_TOKEN\",\"token_type\":\"Bearer\"}",
      )
      |> Ok
    })

  fetch_access_token(fixture.providers, fixture.registration, fixture.scopes)
  |> should.equal(
    Ok(AccessToken(
      token: "SOME_ACCESS_TOKEN",
      token_type: "Bearer",
      expires_in: 0,
      scope: ags.lineitem_scope_url
        <> " "
        <> ags.result_readonly_scope_url
        <> " "
        <> ags.scores_scope_url
        <> " "
        <> nrps.context_membership_readonly_claim_url,
    )),
  )

  memory_provider.cleanup(fixture.memory)
}

pub fn oauth_error_mapping_test() {
  let fixture =
    setup_fixture(fn(_req) {
      response.new(401)
      |> response.set_body(
        "{\"error\":\"invalid_client\",\"error_description\":\"bad secret\",\"error_uri\":\"https://example.com/errors/invalid_client\"}",
      )
      |> Ok
    })

  fetch_access_token(fixture.providers, fixture.registration, fixture.scopes)
  |> should.equal(
    Error(OAuthError(
      error: "invalid_client",
      error_description: Some("bad secret"),
      error_uri: Some("https://example.com/errors/invalid_client"),
    )),
  )

  access_token_error_to_string(OAuthError(
    error: "invalid_client",
    error_description: Some("bad secret"),
    error_uri: Some("https://example.com/errors/invalid_client"),
  ))
  |> should.equal("OAuth token endpoint error (invalid_client): bad secret")

  memory_provider.cleanup(fixture.memory)
}

pub fn non_json_error_body_maps_to_http_status_error_test() {
  let fixture =
    setup_fixture(fn(_req) {
      response.new(500)
      |> response.set_body("gateway unavailable")
      |> Ok
    })

  fetch_access_token(fixture.providers, fixture.registration, fixture.scopes)
  |> should.equal(
    Error(HttpStatusError(status: 500, body: "gateway unavailable")),
  )

  memory_provider.cleanup(fixture.memory)
}

pub fn assertion_claims_include_required_fields_and_hardened_lifetime_test() {
  let fixture = setup_fixture(fn(_req) { Ok(response.new(200)) })

  let options =
    AssertionOptions(
      audience: Some("https://platform.example.com/oauth2"),
      lifetime_seconds: 120,
    )

  let assert Ok(jwt) =
    build_client_assertion(
      fixture.active_jwk,
      "https://platform.example.com/oauth2",
      fixture.registration.client_id,
      options,
    )

  let jose.JoseJwt(claims: claims) = jose.peek(jwt)
  let jose.JoseJws(headers: headers, ..) = jose.peek_protected(jwt)

  decode_claim_string(claims, "iss")
  |> should.equal(Ok(fixture.registration.client_id))

  decode_claim_string(claims, "sub")
  |> should.equal(Ok(fixture.registration.client_id))

  decode_claim_string(claims, "aud")
  |> should.equal(Ok("https://platform.example.com/oauth2"))

  decode_claim_string(headers, "kid")
  |> should.equal(Ok(fixture.active_jwk.kid))

  let assert Ok(iat) = decode_claim_int(claims, "iat")
  let assert Ok(exp) = decode_claim_int(claims, "exp")

  let lifetime_valid = exp - iat > 0 && exp - iat <= 121
  lifetime_valid
  |> should.equal(True)

  decode_claim_string(claims, "jti")
  |> result.map(fn(value) { string.length(value) > 0 })
  |> should.equal(Ok(True))

  memory_provider.cleanup(fixture.memory)
}

pub fn assertion_build_validation_errors_test() {
  let fixture = setup_fixture(fn(_req) { Ok(response.new(200)) })

  build_client_assertion(
    jwk.Jwk(..fixture.active_jwk, kid: ""),
    fixture.registration.access_token_endpoint,
    fixture.registration.client_id,
    AssertionOptions(audience: None, lifetime_seconds: 120),
  )
  |> should.equal(Error(AssertionBuildError("active JWK is missing kid")))

  build_client_assertion(
    fixture.active_jwk,
    fixture.registration.access_token_endpoint,
    fixture.registration.client_id,
    AssertionOptions(audience: None, lifetime_seconds: 0),
  )
  |> should.equal(
    Error(AssertionBuildError("assertion lifetime must be greater than zero")),
  )

  memory_provider.cleanup(fixture.memory)
}

fn setup_fixture(expect_http_post) -> Fixture {
  let assert Ok(memory) = memory_provider.start()
  let assert Ok(data_provider) = memory_provider.data_provider(memory)

  let assert Ok(active_jwk) = jwk.generate()
  memory_provider.create_jwk(memory, active_jwk)

  let assert Ok(#(_, registration)) =
    memory_provider.create_registration(
      memory,
      Registration(
        name: "Example Registration",
        issuer: "http://example.com",
        client_id: "SOME_CLIENT_ID",
        auth_endpoint: "http://example.com/lti/authorize_redirect",
        access_token_endpoint: "http://example.com/auth/token",
        keyset_url: "http://example.com/jwks.json",
      ),
    )

  let scopes = [
    ags.lineitem_scope_url,
    ags.result_readonly_scope_url,
    ags.scores_scope_url,
    nrps.context_membership_readonly_claim_url,
  ]

  let providers =
    providers.Providers(
      data: data_provider,
      http: http_mock_provider.http_provider(expect_http_post),
    )

  Fixture(
    memory: memory,
    providers: providers,
    registration: registration,
    scopes: scopes,
    active_jwk: active_jwk,
  )
}

fn decode_claim_string(claims, key: String) {
  claims
  |> dict.get(key)
  |> result.replace_error(Nil)
  |> result.try(fn(value) {
    decode.run(value, decode.string)
    |> result.replace_error(Nil)
  })
}

fn decode_claim_int(claims, key: String) {
  claims
  |> dict.get(key)
  |> result.replace_error(Nil)
  |> result.try(fn(value) {
    decode.run(value, decode.int)
    |> result.replace_error(Nil)
  })
}
