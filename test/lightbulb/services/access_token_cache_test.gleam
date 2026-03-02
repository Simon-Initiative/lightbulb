import gleam/http/request.{type Request}
import gleam/http/response
import gleam/option.{None, Some}
import gleeunit/should
import lightbulb/jwk
import lightbulb/providers
import lightbulb/providers/http_mock_provider
import lightbulb/providers/memory_provider
import lightbulb/registration.{Registration}
import lightbulb/services/access_token.{AccessToken}
import lightbulb/services/access_token_cache.{CachedToken}

pub fn cache_get_hit_and_stale_test() {
  let cache = access_token_cache.with_refresh_window(60)
  let cache_key =
    access_token_cache.key("issuer", "client", ["scope:one", "scope:two"])

  let cached =
    CachedToken(
      token: AccessToken("cached-token", "Bearer", 3600, "scope:one scope:two"),
      expires_at_unix: 2_000,
    )

  let cache = access_token_cache.put(cache, cache_key, cached)

  access_token_cache.get(cache, cache_key, 1_900)
  |> should.equal(Some(cached))

  access_token_cache.get(cache, cache_key, 1_940)
  |> should.equal(None)
}

pub fn fetch_access_token_with_cache_hit_test() {
  let #(memory, registration, providers) =
    setup(fn(_req: Request(String)) {
      Error("HTTP should not be used for a fresh cache hit")
    })

  let scopes = ["scope:one", "scope:two"]
  let cache_key =
    access_token_cache.key(registration.issuer, registration.client_id, scopes)

  let cache =
    access_token_cache.new()
    |> access_token_cache.put(
      cache_key,
      CachedToken(
        token: AccessToken("cached-token", "Bearer", 3600, "scope:one scope:two"),
        expires_at_unix: 3_000_000_000,
      ),
    )

  access_token_cache.fetch_access_token_with_cache(
    cache,
    providers,
    registration,
    scopes,
  )
  |> should.equal(Ok(#(AccessToken("cached-token", "Bearer", 3600, "scope:one scope:two"), cache)))

  memory_provider.cleanup(memory)
}

pub fn fetch_access_token_with_cache_refresh_test() {
  let #(memory, registration, providers) =
    setup(fn(_req) {
      response.new(200)
      |> response.set_body(
        "{\"access_token\":\"fetched-token\",\"token_type\":\"Bearer\",\"expires_in\":3600,\"scope\":\"scope:one scope:two\"}",
      )
      |> Ok
    })

  let scopes = ["scope:one", "scope:two"]
  let cache_key =
    access_token_cache.key(registration.issuer, registration.client_id, scopes)

  let stale_cache =
    access_token_cache.with_refresh_window(60)
    |> access_token_cache.put(
      cache_key,
      CachedToken(
        token: AccessToken("stale-token", "Bearer", 20, "scope:one scope:two"),
        expires_at_unix: 1,
      ),
    )

  let assert Ok(#(token, refreshed_cache)) =
    access_token_cache.fetch_access_token_with_cache(
      stale_cache,
      providers,
      registration,
      scopes,
    )

  token
  |> should.equal(AccessToken("fetched-token", "Bearer", 3600, "scope:one scope:two"))

  let assert Some(CachedToken(token: cached, ..)) =
    access_token_cache.get(refreshed_cache, cache_key, 2)

  cached
  |> should.equal(AccessToken("fetched-token", "Bearer", 3600, "scope:one scope:two"))

  memory_provider.cleanup(memory)
}

fn setup(expect_http_post) {
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

  let providers =
    providers.Providers(
      data: data_provider,
      http: http_mock_provider.http_provider(expect_http_post),
    )

  #(memory, registration, providers)
}
