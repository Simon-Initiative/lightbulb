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
import lightbulb.{type DataProvider}
import wisp.{type Request, type Response, redirect}

pub fn oidc_login(req: Request, data_provider: DataProvider) -> Response {
  // Get all query and body parameters from the request.
  use params <- all_params(req)

  // Build the OIDC login state and URL response.
  case lightbulb.oidc_login(data_provider, params) {
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
      |> wisp.string_body("OIDC login failed: " <> error)
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
  case lightbulb.validate_launch(data_provider, params, state) {
    Ok(claims) -> {
      wisp.ok()
      |> wisp.string_body("Launch successful! " <> string.inspect(claims))
    }
    Error(e) -> {
      wisp.bad_request()
      |> wisp.string_body("Invalid launch: " <> string.inspect(e))
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

## Development

```sh
gleam test  # Run the tests
```
