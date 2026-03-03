import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/timestamp
import lightbulb/providers.{type Providers}
import lightbulb/registration.{type Registration}
import lightbulb/services/access_token.{
  type AccessToken, type AccessTokenError, AccessToken,
}

const default_refresh_window_seconds = 60

pub type TokenCacheKey {
  TokenCacheKey(issuer: String, client_id: String, scopes_hash: String)
}

pub type CachedToken {
  CachedToken(token: AccessToken, expires_at_unix: Int)
}

pub type TokenCache {
  TokenCache(
    entries: dict.Dict(TokenCacheKey, CachedToken),
    refresh_window_seconds: Int,
  )
}

/// Creates a token cache with the default refresh window.
pub fn new() -> TokenCache {
  TokenCache(
    entries: dict.new(),
    refresh_window_seconds: default_refresh_window_seconds,
  )
}

/// Creates a token cache with a custom refresh window in seconds.
pub fn with_refresh_window(refresh_window_seconds: Int) -> TokenCache {
  let safe_refresh_window = int.max(refresh_window_seconds, 0)
  TokenCache(entries: dict.new(), refresh_window_seconds: safe_refresh_window)
}

fn unix_seconds(value: timestamp.Timestamp) -> Int {
  timestamp.to_unix_seconds_and_nanoseconds(value).0
}

/// Builds a deterministic cache key from issuer, client, and scopes.
pub fn key(
  issuer issuer: String,
  client_id client_id: String,
  scopes scopes: List(String),
) -> TokenCacheKey {
  TokenCacheKey(
    issuer: issuer,
    client_id: client_id,
    scopes_hash: normalize_scopes(scopes),
  )
}

/// Returns a cached token when it is still fresh for the current time.
pub fn get(
  cache: TokenCache,
  cache_key: TokenCacheKey,
  now_unix: Int,
) -> Option(CachedToken) {
  let TokenCache(
    refresh_window_seconds: refresh_window_seconds,
    entries: entries,
  ) = cache

  case dict.get(entries, cache_key) {
    Ok(cached_token) ->
      case token_is_fresh(cached_token, now_unix, refresh_window_seconds) {
        True -> Some(cached_token)
        False -> None
      }

    _ -> None
  }
}

/// Stores a token in the cache for a computed key.
pub fn put(
  cache: TokenCache,
  cache_key: TokenCacheKey,
  cached_token: CachedToken,
) -> TokenCache {
  let TokenCache(entries: entries, ..) = cache
  TokenCache(..cache, entries: dict.insert(entries, cache_key, cached_token))
}

/// Removes a cached token entry.
pub fn invalidate(cache: TokenCache, cache_key: TokenCacheKey) -> TokenCache {
  let TokenCache(entries: entries, ..) = cache
  TokenCache(..cache, entries: dict.delete(entries, cache_key))
}

/// Fetches a token from cache or the OAuth endpoint and returns updated cache state.
pub fn fetch_access_token_with_cache(
  cache: TokenCache,
  providers: Providers,
  registration: Registration,
  scopes: List(String),
) -> Result(#(AccessToken, TokenCache), AccessTokenError) {
  let now_unix = timestamp.system_time() |> unix_seconds
  let cache_key = key(registration.issuer, registration.client_id, scopes)

  case get(cache, cache_key, now_unix) {
    Some(CachedToken(token: token, ..)) -> Ok(#(token, cache))
    None -> {
      use token <- result.try(access_token.fetch_access_token(
        providers,
        registration,
        scopes,
      ))

      maybe_cache_token(cache, cache_key, token, now_unix)
      |> result.map(fn(updated_cache) { #(token, updated_cache) })
    }
  }
}

fn maybe_cache_token(
  cache: TokenCache,
  cache_key: TokenCacheKey,
  token: AccessToken,
  now_unix: Int,
) -> Result(TokenCache, AccessTokenError) {
  let AccessToken(expires_in: expires_in, ..) = token

  use <- bool.guard(when: expires_in <= 0, return: Ok(cache))

  let cached_token =
    CachedToken(token: token, expires_at_unix: now_unix + expires_in)
  Ok(put(cache, cache_key, cached_token))
}

fn token_is_fresh(
  cached_token: CachedToken,
  now_unix: Int,
  refresh_window_seconds: Int,
) -> Bool {
  let CachedToken(expires_at_unix: expires_at_unix, ..) = cached_token
  now_unix + refresh_window_seconds < expires_at_unix
}

fn normalize_scopes(scopes: List(String)) -> String {
  scopes
  |> list.map(string.trim)
  |> list.filter(fn(scope) { scope != "" })
  |> list.sort(fn(left, right) { string.compare(left, right) })
  |> list.unique()
  |> string.join(" ")
}
