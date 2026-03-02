import gleam/dict
import gleam/dynamic
import gleam/list
import gleam/option
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import gleam/uri
import gleeunit/should
import lightbulb/deployment
import lightbulb/errors
import lightbulb/jose
import lightbulb/nonce
import lightbulb/providers/data_provider.{type DataProvider, LoginContext}
import lightbulb/providers/memory_provider
import lightbulb/registration
import lightbulb/tool

type Fixture {
  Fixture(
    memory: memory_provider.MemoryProvider,
    provider: DataProvider,
    issuer: String,
    client_id: String,
    target_link_uri: String,
    state: String,
    nonce: String,
    signing_jwk: dict.Dict(String, String),
    kid: String,
  )
}

fn unix_seconds(value: timestamp.Timestamp) -> Int {
  timestamp.to_unix_seconds_and_nanoseconds(value).0
}

pub fn successful_resource_link_launch_test() {
  let fixture = setup_fixture(option.None)

  let id_token = sign_token(fixture, base_claims(fixture), fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.be_ok()

  memory_provider.cleanup(fixture.memory)
}

pub fn structured_error_to_string_conversion_test() {
  errors.core_error_to_string(errors.NonceValidationError(errors.NonceExpired))
  |> should.equal("Nonce has expired.")

  errors.core_error_to_string(errors.LaunchMissingParam("state"))
  |> should.equal("Missing required launch parameter: state.")
}

pub fn missing_required_claim_failure_test() {
  let fixture = setup_fixture(option.None)

  let claims =
    dict.delete(
      base_claims(fixture),
      "https://purl.imsglobal.org/spec/lti/claim/roles",
    )
  let id_token = sign_token(fixture, claims, fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.JwtInvalidClaim))

  memory_provider.cleanup(fixture.memory)
}

pub fn invalid_version_failure_test() {
  let fixture = setup_fixture(option.None)

  let claims =
    dict.insert(
      base_claims(fixture),
      "https://purl.imsglobal.org/spec/lti/claim/version",
      dynamic.string("1.1.0"),
    )
  let id_token = sign_token(fixture, claims, fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.JwtInvalidClaim))

  memory_provider.cleanup(fixture.memory)
}

pub fn unsupported_message_type_failure_test() {
  let fixture = setup_fixture(option.None)

  let claims =
    dict.insert(
      base_claims(fixture),
      "https://purl.imsglobal.org/spec/lti/claim/message_type",
      dynamic.string("LtiUnknown"),
    )
  let id_token = sign_token(fixture, claims, fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.MessageTypeUnsupported))

  memory_provider.cleanup(fixture.memory)
}

pub fn audience_single_success_test() {
  let fixture = setup_fixture(option.None)
  let id_token = sign_token(fixture, base_claims(fixture), fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.be_ok()

  memory_provider.cleanup(fixture.memory)
}

pub fn audience_multi_with_azp_success_test() {
  let fixture = setup_fixture(option.None)

  let claims =
    base_claims_with_audience(
      fixture,
      dynamic.list([
        dynamic.string("some-other-client"),
        dynamic.string(fixture.client_id),
      ]),
    )
    |> dict.insert("azp", dynamic.string(fixture.client_id))

  let id_token = sign_token(fixture, claims, fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.be_ok()

  memory_provider.cleanup(fixture.memory)
}

pub fn audience_multi_without_azp_failure_test() {
  let fixture = setup_fixture(option.None)

  let claims =
    base_claims_with_audience(
      fixture,
      dynamic.list([
        dynamic.string("some-other-client"),
        dynamic.string(fixture.client_id),
      ]),
    )

  let id_token = sign_token(fixture, claims, fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.AudienceInvalid))

  memory_provider.cleanup(fixture.memory)
}

pub fn audience_azp_not_in_aud_failure_test() {
  let fixture = setup_fixture(option.None)

  let claims =
    base_claims_with_audience(
      fixture,
      dynamic.list([
        dynamic.string("some-other-client"),
        dynamic.string(fixture.client_id),
      ]),
    )
    |> dict.insert("azp", dynamic.string("another-client"))

  let id_token = sign_token(fixture, claims, fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.AudienceInvalid))

  memory_provider.cleanup(fixture.memory)
}

pub fn deployment_mismatch_failure_test() {
  let fixture = setup_fixture(option.None)

  let claims =
    dict.insert(
      base_claims(fixture),
      "https://purl.imsglobal.org/spec/lti/claim/deployment_id",
      dynamic.string("wrong-deployment"),
    )
  let id_token = sign_token(fixture, claims, fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.DeploymentNotFound))

  memory_provider.cleanup(fixture.memory)
}

pub fn state_mismatch_failure_test() {
  let fixture = setup_fixture(option.None)

  let id_token = sign_token(fixture, base_claims(fixture), fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    "different-session-state",
  )
  |> should.equal(Error(errors.StateInvalid))

  memory_provider.cleanup(fixture.memory)
}

pub fn missing_state_context_failure_test() {
  let fixture = setup_fixture(option.None)

  let assert Ok(Nil) = fixture.provider.consume_login_context(fixture.state)

  let id_token = sign_token(fixture, base_claims(fixture), fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.StateNotFound))

  memory_provider.cleanup(fixture.memory)
}

pub fn expired_state_context_failure_test() {
  let fixture = setup_fixture(option.None)

  let assert Ok(Nil) = fixture.provider.save_login_context(
    LoginContext(
      state: fixture.state,
      target_link_uri: fixture.target_link_uri,
      issuer: fixture.issuer,
      client_id: fixture.client_id,
      expires_at:
        timestamp.system_time()
        |> timestamp.add(duration.minutes(-10)),
    ),
  )

  let id_token = sign_token(fixture, base_claims(fixture), fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.StateNotFound))

  memory_provider.cleanup(fixture.memory)
}

pub fn target_link_uri_mismatch_failure_test() {
  let fixture = setup_fixture(option.None)

  let claims =
    dict.insert(
      base_claims(fixture),
      "https://purl.imsglobal.org/spec/lti/claim/target_link_uri",
      dynamic.string("https://tool.example.com/other"),
    )
  let id_token = sign_token(fixture, claims, fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.TargetLinkUriMismatch))

  memory_provider.cleanup(fixture.memory)
}

pub fn expired_nonce_failure_test() {
  let fixture = setup_fixture(option.None)

  let expired_nonce = "expired-nonce"
  memory_provider.insert_nonce(
    fixture.memory,
    nonce.Nonce(
      expired_nonce,
      timestamp.system_time()
      |> timestamp.add(duration.minutes(-10)),
    ),
  )

  let claims = dict.insert(base_claims(fixture), "nonce", dynamic.string(expired_nonce))
  let id_token = sign_token(fixture, claims, fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.NonceValidationError(errors.NonceExpired)))

  memory_provider.cleanup(fixture.memory)
}

pub fn replayed_nonce_failure_test() {
  let fixture = setup_fixture(option.None)

  let id_token = sign_token(fixture, base_claims(fixture), fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.be_ok()

  let assert Ok(Nil) = fixture.provider.save_login_context(
    LoginContext(
      state: fixture.state,
      target_link_uri: fixture.target_link_uri,
      issuer: fixture.issuer,
      client_id: fixture.client_id,
      expires_at:
        timestamp.system_time()
        |> timestamp.add(duration.minutes(5)),
    ),
  )

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.NonceValidationError(errors.NonceReplayed)))

  memory_provider.cleanup(fixture.memory)
}

pub fn unknown_kid_failure_test() {
  let fixture = setup_fixture(option.None)

  let id_token = sign_token(fixture, base_claims(fixture), "unknown-kid")

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.JwtInvalidSignature))

  memory_provider.cleanup(fixture.memory)
}

pub fn invalid_signature_failure_test() {
  let fixture = setup_fixture(option.None)
  let #(_, attacker_jwk) = jose.generate_key(jose.Rsa(2048)) |> jose.to_map()

  let id_token = sign_token_with_jwk(attacker_jwk, base_claims(fixture), fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.JwtInvalidSignature))

  memory_provider.cleanup(fixture.memory)
}

pub fn malformed_keyset_failure_test() {
  let fixture = setup_fixture(option.Some("inline_jwks:not-json"))

  let id_token = sign_token(fixture, base_claims(fixture), fixture.kid)

  tool.validate_launch(
    fixture.provider,
    dict.from_list([#("id_token", id_token), #("state", fixture.state)]),
    fixture.state,
  )
  |> should.equal(Error(errors.JwtInvalidClaim))

  memory_provider.cleanup(fixture.memory)
}

fn setup_fixture(keyset_url_override: option.Option(String)) -> Fixture {
  let issuer = "https://platform.example.com"
  let client_id = "tool-client"
  let target_link_uri = "https://tool.example.com/launch"
  let kid = "platform-kid"

  let assert Ok(memory) = memory_provider.start()
  let assert Ok(provider) = memory_provider.data_provider(memory)

  let #(_, signing_jwk) = jose.generate_key(jose.Rsa(2048)) |> jose.to_map()
  let #(_, public_jwk_base) =
    signing_jwk
    |> jose.from_map()
    |> jose.to_public()
    |> jose.to_map()

  let public_jwk = dict.insert(public_jwk_base, "kid", kid)

  let keyset_url = case keyset_url_override {
    option.Some(override) -> override
    option.None -> "inline_jwks:" <> build_keyset_json(public_jwk)
  }

  let registration =
    registration.Registration(
      name: "test-platform",
      issuer: issuer,
      client_id: client_id,
      auth_endpoint: "https://platform.example.com/auth",
      access_token_endpoint: "https://platform.example.com/token",
      keyset_url: keyset_url,
    )

  let assert Ok(#(registration_id, _)) =
    memory_provider.create_registration(memory, registration)

  let assert Ok(#(_, _)) =
    memory_provider.create_deployment(
      memory,
      deployment.Deployment("deployment-1", registration_id),
    )

  let login_params =
    dict.from_list([
      #("iss", issuer),
      #("client_id", client_id),
      #("login_hint", "student-1"),
      #("target_link_uri", target_link_uri),
    ])

  let assert Ok(#(state, redirect_url)) = tool.oidc_login(provider, login_params)
  let nonce = redirect_query_param(redirect_url, "nonce")

  Fixture(memory, provider, issuer, client_id, target_link_uri, state, nonce, signing_jwk, kid)
}

fn build_keyset_json(jwk: dict.Dict(String, String)) -> String {
  let key_json_parts =
    jwk
    |> dict.to_list()
    |> list.map(fn(entry) {
      let #(key, value) = entry
      "\"" <> key <> "\":\"" <> value <> "\""
    })

  "{\"keys\":[{" <> string.join(key_json_parts, ",") <> "}]}"
}

fn redirect_query_param(url: String, key: String) -> String {
  let assert [_, query] = string.split(url, "?")
  let assert Ok(params) = uri.parse_query(query)
  let assert Ok(value) = list.key_find(params, key)

  value
}

fn sign_token(fixture: Fixture, claims: dict.Dict(String, dynamic.Dynamic), kid: String) {
  sign_token_with_jwk(fixture.signing_jwk, claims, kid)
}

fn sign_token_with_jwk(
  jwk: dict.Dict(String, String),
  claims: dict.Dict(String, dynamic.Dynamic),
  kid: String,
) -> String {
  let jws =
    dict.from_list([#("alg", "RS256"), #("typ", "JWT"), #("kid", kid)])

  let #(_, jose_jwt) = jose.sign_with_jws(jwk, jws, claims)
  let #(_, compact_signed) = jose.compact(jose_jwt)

  compact_signed
}

fn base_claims(fixture: Fixture) {
  base_claims_with_audience(fixture, dynamic.string(fixture.client_id))
}

fn base_claims_with_audience(fixture: Fixture, aud: dynamic.Dynamic) {
  let now = timestamp.system_time()
  let exp =
    timestamp.add(now, duration.minutes(5))
    |> unix_seconds
  let iat = unix_seconds(now)

  dict.from_list([
    #("iss", dynamic.string(fixture.issuer)),
    #("aud", aud),
    #("exp", dynamic.int(exp)),
    #("iat", dynamic.int(iat)),
    #("nonce", dynamic.string(fixture.nonce)),
    #(
      "https://purl.imsglobal.org/spec/lti/claim/message_type",
      dynamic.string("LtiResourceLinkRequest"),
    ),
    #(
      "https://purl.imsglobal.org/spec/lti/claim/version",
      dynamic.string("1.3.0"),
    ),
    #(
      "https://purl.imsglobal.org/spec/lti/claim/deployment_id",
      dynamic.string("deployment-1"),
    ),
    #(
      "https://purl.imsglobal.org/spec/lti/claim/target_link_uri",
      dynamic.string(fixture.target_link_uri),
    ),
    #(
      "https://purl.imsglobal.org/spec/lti/claim/resource_link",
      dynamic.properties([
        #(dynamic.string("id"), dynamic.string("resource-1")),
      ]),
    ),
    #(
      "https://purl.imsglobal.org/spec/lti/claim/roles",
      dynamic.list([
        dynamic.string("http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"),
      ]),
    ),
  ])
}
