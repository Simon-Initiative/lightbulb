import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/option.{Some}
import gleeunit/should
import lightbulb/providers/http_mock_provider
import lightbulb/services/access_token.{AccessToken}
import lightbulb/services/ags
import lightbulb/services/ags/line_item.{LineItem}
import lightbulb/services/ags/score.{Score}

pub fn post_score_test() {
  let score =
    Score(
      score_given: 1.0,
      score_maximum: 2.0,
      timestamp: "2023-10-01T00:00:00Z",
      user_id: "user123",
      comment: "Great job!",
      activity_progress: "Completed",
      grading_progress: "FullyGraded",
    )

  let line_item =
    LineItem(
      id: Some("https://lms.example.com/context/2923/lineitems/1"),
      score_maximum: 2.0,
      label: "Test Line Item",
      resource_id: "resource123",
    )

  let access_token =
    AccessToken(
      token: "SOME_ACCESS_TOKEN",
      token_type: "Bearer",
      expires_in: 3600,
      scope: "some scopes",
    )

  let expect_http_post = fn(req: Request(String)) {
    req.scheme
    |> should.equal(http.Https)

    req.host
    |> should.equal("lms.example.com")

    req.path
    |> should.equal("/context/2923/lineitems/1/scores")

    req.method
    |> should.equal(http.Post)

    response.new(200)
    |> response.set_body("{}")
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_post)

  ags.post_score(http_provider, score, line_item, access_token)
  |> should.be_ok()
}
