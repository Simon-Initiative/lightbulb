import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/option
import gleeunit/should
import lightbulb/http/link_header.{PageLinks}
import lightbulb/providers/http_mock_provider
import lightbulb/services/access_token.{type AccessToken, AccessToken}
import lightbulb/services/nrps
import lightbulb/services/nrps/membership.{Membership}

pub fn next_link_continuation_flow_test() {
  let expect_http_get = fn(req: request.Request(String)) {
    req.path
    |> should.equal("/context/2923/memberships")

    req.query
    |> should.equal(option.Some("page=2"))

    response.new(200)
    |> response.set_header(
      "link",
      "<https://lms.example.com/context/2923/memberships?page=3>; rel=\"next\", <https://lms.example.com/context/2923/memberships?since=100>; rel=\"differences\"",
    )
    |> response.set_body(
      "{\"members\":[{\"user_id\":\"user-2\",\"roles\":[\"Learner\"]}]}",
    )
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  nrps.fetch_next_memberships_page(
    http_provider,
    "https://lms.example.com/context/2923/memberships?page=2",
    fixture_access_token(),
  )
  |> should.equal(
    Ok(nrps.MembershipsPage(
      members: [
        Membership(
          user_id: "user-2",
          roles: ["Learner"],
          status: option.None,
          name: option.None,
          given_name: option.None,
          family_name: option.None,
          middle_name: option.None,
          email: option.None,
          picture: option.None,
          lis_person_sourcedid: option.None,
        ),
      ],
      links: PageLinks(
        next: option.Some(
          "https://lms.example.com/context/2923/memberships?page=3",
        ),
        differences: option.Some(
          "https://lms.example.com/context/2923/memberships?since=100",
        ),
        prev: option.None,
        first: option.None,
        last: option.None,
      ),
    )),
  )
}

pub fn differences_link_continuation_flow_test() {
  let expect_http_get = fn(req: request.Request(String)) {
    req.path
    |> should.equal("/context/2923/memberships")

    req.query
    |> should.equal(option.Some("since=100"))

    response.new(200)
    |> response.set_body("{\"members\":[]}")
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  nrps.fetch_differences_memberships_page(
    http_provider,
    "https://lms.example.com/context/2923/memberships?since=100",
    fixture_access_token(),
  )
  |> should.equal(
    Ok(nrps.MembershipsPage(
      members: [],
      links: PageLinks(
        next: option.None,
        differences: option.None,
        prev: option.None,
        first: option.None,
        last: option.None,
      ),
    )),
  )
}

pub fn malformed_link_header_fallback_behavior_test() {
  let expect_http_get = fn(_req: request.Request(String)) {
    response.new(200)
    |> response.set_header("link", "broken-link")
    |> response.set_body("{\"members\":[]}")
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  nrps.fetch_memberships_with_options(
    http_provider,
    "https://lms.example.com/context/2923/memberships",
    nrps.default_memberships_query(),
    fixture_access_token(),
  )
  |> should.equal(
    Ok(nrps.MembershipsPage(
      members: [],
      links: PageLinks(
        next: option.None,
        differences: option.None,
        prev: option.None,
        first: option.None,
        last: option.None,
      ),
    )),
  )
}

pub fn access_token_header_for_nrps_calls_test() {
  let expect_http_get = fn(req: request.Request(String)) {
    req.method
    |> should.equal(http.Get)

    req
    |> request.get_header("authorization")
    |> should.equal(Ok("Bearer SOME_ACCESS_TOKEN"))

    response.new(200)
    |> response.set_body("{\"members\":[]}")
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  nrps.fetch_memberships_with_options(
    http_provider,
    "https://lms.example.com/context/2923/memberships",
    nrps.default_memberships_query(),
    fixture_access_token(),
  )
  |> should.be_ok()
}

fn fixture_access_token() -> AccessToken {
  AccessToken(
    token: "SOME_ACCESS_TOKEN",
    token_type: "Bearer",
    expires_in: 3600,
    scope: "some scopes",
  )
}
