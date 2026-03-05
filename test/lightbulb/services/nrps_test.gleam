import gleam/dict
import gleam/dynamic
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/json
import gleam/option
import gleam/string
import gleeunit/should
import lightbulb/providers/http_mock_provider
import lightbulb/services/access_token.{type AccessToken, AccessToken}
import lightbulb/services/nrps
import lightbulb/services/nrps/membership

pub fn fetch_memberships_test() {
  let expect_http_get = fn(req: request.Request(String)) {
    req.path
    |> should.equal("/lti/courses/350/names_and_roles")

    req.method
    |> should.equal(http.Get)

    req.query
    |> should.equal(option.None)

    req
    |> request.get_header("accept")
    |> should.equal(Ok(
      "application/vnd.ims.lti-nrps.v2.membershipcontainer+json",
    ))

    response.new(200)
    |> response.set_body(
      "{
      \"members\": [
        {
          \"user_id\": \"12345\",
          \"roles\": [\"Instructor\"]
        },
        {
          \"user_id\": \"67890\",
          \"roles\": [\"Learner\"],
          \"name\": \"Jane Smith\"
        }
      ]
    }",
    )
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  let result =
    nrps.fetch_memberships(
      http_provider,
      "https://lms.example.com/lti/courses/350/names_and_roles",
      fixture_access_token(),
    )

  result
  |> should.equal(
    Ok([
      membership.Membership(
        user_id: "12345",
        roles: ["Instructor"],
        status: option.None,
        name: option.None,
        given_name: option.None,
        family_name: option.None,
        middle_name: option.None,
        email: option.None,
        picture: option.None,
        lis_person_sourcedid: option.None,
      ),
      membership.Membership(
        user_id: "67890",
        roles: ["Learner"],
        status: option.None,
        name: option.Some("Jane Smith"),
        given_name: option.None,
        family_name: option.None,
        middle_name: option.None,
        email: option.None,
        picture: option.None,
        lis_person_sourcedid: option.None,
      ),
    ]),
  )
}

pub fn options_query_serialization_test() {
  let expect_http_get = fn(req: request.Request(String)) {
    req.query
    |> option.unwrap("")
    |> string.contains("role=Instructor")
    |> should.equal(True)

    req.query
    |> option.unwrap("")
    |> string.contains("limit=10")
    |> should.equal(True)

    req.query
    |> option.unwrap("")
    |> string.contains("rlid=resource-link-123")
    |> should.equal(True)

    response.new(200)
    |> response.set_body("{\"members\":[]}")
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  nrps.fetch_memberships_with_options(
    http_provider,
    "https://lms.example.com/lti/courses/350/names_and_roles",
    nrps.MembershipsQuery(
      role: option.Some("Instructor"),
      limit: option.Some(10),
      rlid: option.Some("resource-link-123"),
      url: option.None,
    ),
    fixture_access_token(),
  )
  |> should.be_ok()
}

pub fn get_nrps_claim_minimal_valid_test() {
  let claims =
    dict.from_list([
      #(
        nrps.nrps_claim_url,
        dynamic.properties([
          #(
            dynamic.string("context_memberships_url"),
            dynamic.string("https://lms.example.com/context/100/memberships"),
          ),
          #(
            dynamic.string("service_versions"),
            dynamic.list([dynamic.string("2.0")]),
          ),
        ]),
      ),
    ])

  nrps.get_nrps_claim(claims)
  |> should.equal(
    Ok(
      nrps.NrpsClaim(
        context_memberships_url: "https://lms.example.com/context/100/memberships",
        service_versions: ["2.0"],
      ),
    ),
  )
}

pub fn get_nrps_claim_invalid_missing_service_versions_test() {
  let claims =
    dict.from_list([
      #(
        nrps.nrps_claim_url,
        dynamic.properties([
          #(
            dynamic.string("context_memberships_url"),
            dynamic.string("https://lms.example.com/context/100/memberships"),
          ),
        ]),
      ),
    ])

  nrps.get_nrps_claim(claims)
  |> should.equal(Error(nrps.ClaimInvalid))
}

pub fn scope_availability_helpers_test() {
  let claims =
    dict.from_list([
      #(
        nrps.nrps_claim_url,
        dynamic.properties([
          #(
            dynamic.string("context_memberships_url"),
            dynamic.string("https://lms.example.com/context/100/memberships"),
          ),
          #(
            dynamic.string("service_versions"),
            dynamic.list([dynamic.string("2.0")]),
          ),
          #(
            dynamic.string("scope"),
            dynamic.list([
              dynamic.string(nrps.context_membership_readonly_claim_url),
            ]),
          ),
        ]),
      ),
    ])

  nrps.can_read_memberships(claims)
  |> should.equal(True)

  nrps.nrps_available(claims)
  |> should.equal(True)
}

pub fn require_can_read_memberships_failure_test() {
  let claims =
    dict.from_list([
      #(
        nrps.nrps_claim_url,
        dynamic.properties([
          #(
            dynamic.string("context_memberships_url"),
            dynamic.string("https://lms.example.com/context/100/memberships"),
          ),
          #(
            dynamic.string("service_versions"),
            dynamic.list([dynamic.string("2.0")]),
          ),
          #(dynamic.string("scope"), dynamic.list([])),
        ]),
      ),
    ])

  nrps.require_can_read_memberships(claims)
  |> should.equal(
    Error(nrps.ScopeInsufficient(nrps.context_membership_readonly_claim_url)),
  )
}

pub fn minimal_member_decode_test() {
  json.parse(
    "{\"user_id\":\"u-1\",\"roles\":[\"Learner\"]}",
    membership.decoder(),
  )
  |> should.equal(
    Ok(membership.Membership(
      user_id: "u-1",
      roles: ["Learner"],
      status: option.None,
      name: option.None,
      given_name: option.None,
      family_name: option.None,
      middle_name: option.None,
      email: option.None,
      picture: option.None,
      lis_person_sourcedid: option.None,
    )),
  )
}

pub fn expanded_member_decode_test() {
  json.parse(
    "{\"user_id\":\"u-2\",\"roles\":[\"Instructor\"],\"status\":\"active\",\"name\":\"Alex Smith\",\"given_name\":\"Alex\",\"family_name\":\"Smith\",\"middle_name\":\"Q\",\"email\":\"alex@example.edu\",\"picture\":\"https://example.edu/alex.png\",\"lis_person_sourcedid\":\"sis-123\"}",
    membership.decoder(),
  )
  |> should.equal(
    Ok(membership.Membership(
      user_id: "u-2",
      roles: ["Instructor"],
      status: option.Some("active"),
      name: option.Some("Alex Smith"),
      given_name: option.Some("Alex"),
      family_name: option.Some("Smith"),
      middle_name: option.Some("Q"),
      email: option.Some("alex@example.edu"),
      picture: option.Some("https://example.edu/alex.png"),
      lis_person_sourcedid: option.Some("sis-123"),
    )),
  )
}

pub fn missing_required_keys_failure_test() {
  let result = json.parse("{\"roles\":[\"Learner\"]}", membership.decoder())

  case result {
    Error(_) -> True |> should.equal(True)
    Ok(_) -> False |> should.equal(True)
  }
}

fn fixture_access_token() -> AccessToken {
  AccessToken(
    token: "SOME_ACCESS_TOKEN",
    token_type: "Bearer",
    expires_in: 3600,
    scope: "some scopes",
  )
}
