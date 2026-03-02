# 💡 lightbulb

A library for building LTI 1.3 tools in Gleam

[![Package Version](https://img.shields.io/hexpm/v/lightbulb)](https://hex.pm/packages/lightbulb)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/lightbulb/)

### Installation

```sh
gleam add lightbulb@1
```

### Usage

The example below shows how to use the library in a Gleam Wisp application. It includes two
endpoints: one for OIDC login and another for validating the launch request. For a complete
example, see the [lti-example-tool](https://github.com/Simon-Initiative/lti-example-tool) repository.

```gleam
import gleam/dict.{type Dict}
import gleam/http
import gleam/http/cookie
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/option.{Some}
import gleam/string
import lightbulb/errors
import lightbulb/providers/data_provider.{type DataProvider}
import lightbulb/tool
import wisp.{type Request, type Response, redirect}

pub fn oidc_login(req: Request, data_provider: DataProvider) -> Response {
  // Get all query and body parameters from the request.
  use params <- all_params(req)

  // Build the OIDC login state and URL response.
  case tool.oidc_login(data_provider, params) {
    Ok(#(state, redirect_url)) -> {
      use <- set_cookie(
        "state",
        state,
        cookie.Attributes(
          ..cookie.defaults(http.Https),
          same_site: Some(cookie.None),
          max_age: option.Some(60 * 60 * 24),
        ),
      )

      redirect(to: redirect_url)
    }
    Error(error) ->
      wisp.internal_server_error()
      |> wisp.string_body(
        "OIDC login failed: " <> errors.core_error_to_string(error),
      )
  }
}

pub fn validate_launch(req: Request, data_provider: DataProvider) -> Response {
  // Get all query and body parameters from the request.
  use params <- all_params(req)

  // Get the state cookie that was set during the OIDC login.
  use state <- require_cookie(req, "state", or_else: fn() {
    wisp.bad_request()
    |> wisp.string_body("Required 'state' cookie not found")
  })

  // Validate the launch request using the parameters and state.
  case tool.validate_launch(data_provider, params, state) {
    Ok(claims) -> {
      wisp.ok()
      |> wisp.string_body("Launch successful! " <> string.inspect(claims))
    }
    Error(e) -> {
      wisp.bad_request()
      |> wisp.string_body(
        "Invalid launch: " <> errors.core_error_to_string(e),
      )
    }
  }
}

/// Helper functions

fn all_params(
  req: Request,
  cb: fn(Dict(String, String)) -> Response,
) -> Response {
  use formdata <- wisp.require_form(req)

  // Combine query and body parameters into a single dictionary. Body parameters
  // take precedence over query parameters.
  let params =
    wisp.get_query(req)
    |> dict.from_list()
    |> dict.merge(dict.from_list(formdata.values))

  cb(params)
}

fn set_cookie(
  name: String,
  value: String,
  attributes: cookie.Attributes,
  cb: fn() -> Response,
) -> Response {
  cb()
  |> response.set_cookie(name, value, attributes)
}

fn require_cookie(
  req: Request,
  cookie_name: String,
  or_else bail: fn() -> Response,
  cb cb: fn(String) -> Response,
) -> Response {
  case get_cookie(req, cookie_name) {
    Ok(cookie) -> cb(cookie)
    Error(_) -> bail()
  }
}

fn get_cookie(req: Request, name name: String) -> Result(String, Nil) {
  req
  |> request.get_cookies
  |> list.key_find(name)
}

```

Further documentation can be found at <https://hexdocs.pm/lightbulb>.

For API changes across versions, see [`CHANGELOG.md`](./CHANGELOG.md).

### OAuth Service Tokens

`lightbulb/services/access_token` now provides both:
- `fetch_access_token/3 -> Result(AccessToken, String)` for backward compatibility.
- `fetch_access_token_typed/3 -> Result(AccessToken, AccessTokenError)` for structured
  OAuth error handling (`OAuthError`, `HttpStatusError`, `DecodeError`, etc.).

Optional token caching is available in `lightbulb/services/access_token_cache`:
- `TokenCacheKey` keyed by issuer/client/scopes.
- `fetch_access_token_with_cache/4` wrapper for cache hit/miss/stale refresh flows.

For custom assertion audience/TTL, use:
- `default_assertion_options/0`
- `fetch_access_token_with_options/4`

### AGS (Assignments and Grades)

`lightbulb/services/ags` now includes full AGS line-item CRUD, results retrieval,
scope helpers, and pagination metadata support.

Typed APIs:
- `post_score/4`
- `get_line_item/3`
- `list_line_items/4 -> Result(Paged(LineItem), AgsError)`
- `create_line_item/6`
- `fetch_or_create_line_item/7`
- `update_line_item/3`
- `delete_line_item/3`
- `list_results/4 -> Result(Paged(ags/result.Result), AgsError)`
- Scope helpers: `can_read_line_items/1`, `can_write_line_items/1`,
  `can_post_scores/1`, `can_read_results/1`
- Guard helpers: `require_can_read_line_items/1`, `require_can_write_line_items/1`,
  `require_can_post_scores/1`, `require_can_read_results/1`

Compatibility note:
- `grade_passback_available/1` now reflects score-post capability (`scope/score`),
  not results-read capability.
- `LineItem` includes AGS optional fields:
  `resource_link_id`, `tag`, `start_date_time`, `end_date_time`, `grades_released`.

### NRPS (Names and Roles)

`lightbulb/services/nrps` now provides typed NRPS APIs for claim decode,
scope checks, filtered membership fetches, and pagination links.

Key APIs:
- `get_nrps_claim/1 -> Result(NrpsClaim, NrpsError)`
- `can_read_memberships/1` and `require_can_read_memberships/1`
- `fetch_memberships_with_options/4 -> Result(MembershipsPage, NrpsError)`
- `fetch_next_memberships_page/3`
- `fetch_differences_memberships_page/3`

`fetch_memberships/3` remains as a compatibility wrapper and returns only
`List(Membership)` (it calls the options API with `default_memberships_query/0`).

```gleam
import gleam/option
import gleam/result
import lightbulb/services/nrps

fn load_members(http_provider, claims, access_token) {
  use <- result.try(nrps.require_can_read_memberships(claims))
  use service_url <- result.try(nrps.get_membership_service_url(claims))

  let query =
    nrps.MembershipsQuery(
      ..nrps.default_memberships_query(),
      role: option.Some("Instructor"),
      limit: option.Some(50),
    )

  use page <- result.try(
    nrps.fetch_memberships_with_options(
      http_provider,
      service_url,
      query,
      access_token,
    ),
  )

  let nrps.MembershipsPage(members: members, links: links) = page

  // Follow `links.next` with `fetch_next_memberships_page/3` or
  // `links.differences` with `fetch_differences_memberships_page/3`.
  Ok(#(members, links))
}
```

Migration note:
- `Membership` now requires only `user_id` and `roles`; profile fields are optional:
  `status`, `name`, `given_name`, `family_name`, `middle_name`, `email`,
  `picture`, `lis_person_sourcedid`.

### Deep Linking

Deep-link launches can be decoded from validated launch claims, then answered with a
signed Deep Linking response JWT and form-post payload.

```gleam
import gleam/http/response
import gleam/option
import gleam/result
import lightbulb/deep_linking
import lightbulb/deep_linking/content_item
import lightbulb/errors
import wisp.{type Request, type Response}

pub fn deep_linking_response(
  _req: Request,
  data_provider,
  claims,
) -> Response {
  case build_deep_linking_response_html(data_provider, claims) {
    Ok(html) ->
      wisp.ok()
      |> response.set_header("content-type", "text/html; charset=utf-8")
      |> wisp.string_body(html)

    Error(error) ->
      wisp.bad_request()
      |> wisp.string_body(
        "Deep linking response failed: "
        <> errors.deep_linking_error_to_string(error),
      )
  }
}

fn build_deep_linking_response_html(data_provider, claims) {
  use settings <- result.try(deep_linking.get_deep_linking_settings(claims))
  use active_jwk <- result.try(data_provider.get_active_jwk())

  let items = [
    content_item.lti_resource_link(
      option.Some("https://tool.example.com/launch/resource-1"),
      option.Some("Resource 1"),
      option.None,
      option.None,
      option.None,
    ),
  ]

  use jwt <- result.try(
    deep_linking.build_response_jwt(
      request_claims: claims,
      settings: settings,
      items: items,
      options: deep_linking.default_response_options(),
      active_jwk: active_jwk,
    ),
  )

  deep_linking.build_response_form_post(settings.deep_link_return_url, jwt)
}
```

### DataProvider Adapter

Custom providers can compose launch-context storage separately via
`lightbulb/providers/data_provider.LaunchContextProvider` and
`data_provider.from_parts(...)`, while preserving the existing `DataProvider`
shape consumed by `tool.oidc_login` and `tool.validate_launch`.
Provider interfaces use typed errors (`LaunchContextError`, `ProviderError`)
instead of string-coded error identifiers.

## Development

```sh
gleam test  # Run the tests
```
