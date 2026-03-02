import gleam/dict
import gleam/dynamic
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/list
import gleam/option
import gleam/string
import gleeunit/should
import lightbulb/http/link_header.{PageLinks}
import lightbulb/providers/http_mock_provider
import lightbulb/services/access_token.{type AccessToken, AccessToken}
import lightbulb/services/ags
import lightbulb/services/ags/line_item.{type LineItem, LineItem}
import lightbulb/services/ags/result as ags_result
import lightbulb/services/ags/score.{type Score, Score}

pub fn post_score_test() {
  let score = fixture_score()
  let line_item =
    fixture_line_item("https://lms.example.com/context/2923/lineitems/1")

  let expect_http_post = fn(req: request.Request(String)) {
    req.path
    |> should.equal("/context/2923/lineitems/1/scores")

    req.method
    |> should.equal(http.Post)

    req
    |> request.get_header("content-type")
    |> should.equal(Ok("application/vnd.ims.lis.v1.score+json"))

    req
    |> request.get_header("accept")
    |> should.equal(Ok("application/json"))

    response.new(202)
    |> response.set_body("{}")
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_post)

  ags.post_score(http_provider, score, line_item, fixture_access_token())
  |> should.be_ok()
}

pub fn create_line_item_test() {
  let expect_http_post = fn(req: request.Request(String)) {
    req.method
    |> should.equal(http.Post)

    req.path
    |> should.equal("/context/2923/lineitems")

    req
    |> request.get_header("accept")
    |> should.equal(Ok("application/vnd.ims.lis.v2.lineitem+json"))

    req
    |> request.get_header("content-type")
    |> should.equal(Ok("application/vnd.ims.lis.v2.lineitem+json"))

    req.body
    |> string.contains("\"resourceId\":\"resource123\"")
    |> should.equal(True)

    response.new(201)
    |> response.set_body(
      "{\"id\":\"https://lms.example.com/context/2923/lineitems/5\",\"scoreMaximum\":10.0,\"label\":\"Unit 1\",\"resourceId\":\"resource123\",\"resourceLinkId\":\"rl-1\",\"tag\":\"unit\",\"gradesReleased\":true}",
    )
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_post)

  ags.create_line_item(
    http_provider,
    "https://lms.example.com/context/2923/lineitems",
    "resource123",
    10.0,
    "Unit 1",
    fixture_access_token(),
  )
  |> should.equal(
    Ok(LineItem(
      id: option.Some("https://lms.example.com/context/2923/lineitems/5"),
      score_maximum: 10.0,
      label: "Unit 1",
      resource_id: "resource123",
      resource_link_id: option.Some("rl-1"),
      tag: option.Some("unit"),
      start_date_time: option.None,
      end_date_time: option.None,
      grades_released: option.Some(True),
    )),
  )
}

pub fn fetch_or_create_line_item_existing_test() {
  let expect_http_get = fn(req: request.Request(String)) {
    req.method
    |> should.equal(http.Get)

    req.path
    |> should.equal("/context/2923/lineitems")

    req.query
    |> option.unwrap("")
    |> string.contains("resource_id=resource123")
    |> should.equal(True)

    req.query
    |> option.unwrap("")
    |> string.contains("limit=1")
    |> should.equal(True)

    response.new(200)
    |> response.set_body(
      "[{\"id\":\"https://lms.example.com/context/2923/lineitems/8\",\"scoreMaximum\":10.0,\"label\":\"Unit 1\",\"resourceId\":\"resource123\"}]",
    )
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  ags.fetch_or_create_line_item(
    http_provider,
    "https://lms.example.com/context/2923/lineitems",
    "resource123",
    fn() { 10.0 },
    "Unit 1",
    fixture_access_token(),
  )
  |> should.equal(
    Ok(LineItem(
      id: option.Some("https://lms.example.com/context/2923/lineitems/8"),
      score_maximum: 10.0,
      label: "Unit 1",
      resource_id: "resource123",
      resource_link_id: option.None,
      tag: option.None,
      start_date_time: option.None,
      end_date_time: option.None,
      grades_released: option.None,
    )),
  )
}

pub fn get_line_item_test() {
  let expect_http_get = fn(req: request.Request(String)) {
    req.method
    |> should.equal(http.Get)

    req.path
    |> should.equal("/context/2923/lineitems/1")

    req
    |> request.get_header("accept")
    |> should.equal(Ok("application/vnd.ims.lis.v2.lineitem+json"))

    response.new(200)
    |> response.set_body(
      "{\"id\":\"https://lms.example.com/context/2923/lineitems/1\",\"scoreMaximum\":2.0,\"label\":\"Test Line Item\",\"resourceId\":\"resource123\"}",
    )
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  ags.get_line_item(
    http_provider,
    "https://lms.example.com/context/2923/lineitems/1",
    fixture_access_token(),
  )
  |> should.be_ok()
}

pub fn list_line_items_paging_test() {
  let expect_http_get = fn(req: request.Request(String)) {
    req.method
    |> should.equal(http.Get)

    req.path
    |> should.equal("/context/2923/lineitems")

    req.query
    |> option.unwrap("")
    |> string.contains("resource_id=resource123")
    |> should.equal(True)

    req.query
    |> option.unwrap("")
    |> string.contains("tag=quiz")
    |> should.equal(True)

    req.query
    |> option.unwrap("")
    |> string.contains("limit=5")
    |> should.equal(True)

    req
    |> request.get_header("accept")
    |> should.equal(Ok("application/vnd.ims.lis.v2.lineitemcontainer+json"))

    response.new(200)
    |> response.set_header(
      "link",
      "<https://lms.example.com/context/2923/lineitems?page=2>; rel=\"next\", <https://lms.example.com/context/2923/lineitems?page=1>; rel=\"first\"",
    )
    |> response.set_body(
      "[{\"id\":\"https://lms.example.com/context/2923/lineitems/8\",\"scoreMaximum\":10.0,\"label\":\"Unit 1\",\"resourceId\":\"resource123\"}]",
    )
    |> Ok
  }

  let query =
    ags.LineItemsQuery(
      resource_link_id: option.None,
      resource_id: option.Some("resource123"),
      tag: option.Some("quiz"),
      limit: option.Some(5),
    )

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  let assert Ok(ags.Paged(items: items, links: links)) =
    ags.list_line_items(
      http_provider,
      "https://lms.example.com/context/2923/lineitems",
      query,
      fixture_access_token(),
    )

  list.length(items)
  |> should.equal(1)

  links
  |> should.equal(PageLinks(
    next: option.Some("https://lms.example.com/context/2923/lineitems?page=2"),
    prev: option.None,
    first: option.Some("https://lms.example.com/context/2923/lineitems?page=1"),
    last: option.None,
  ))
}

pub fn update_line_item_test() {
  let expect_http_put = fn(req: request.Request(String)) {
    req.method
    |> should.equal(http.Put)

    req.path
    |> should.equal("/context/2923/lineitems/1")

    req
    |> request.get_header("accept")
    |> should.equal(Ok("application/vnd.ims.lis.v2.lineitem+json"))

    response.new(200)
    |> response.set_body(
      "{\"id\":\"https://lms.example.com/context/2923/lineitems/1\",\"scoreMaximum\":3.0,\"label\":\"Updated\",\"resourceId\":\"resource123\"}",
    )
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_put)

  ags.update_line_item(
    http_provider,
    LineItem(
      id: option.Some("https://lms.example.com/context/2923/lineitems/1"),
      score_maximum: 3.0,
      label: "Updated",
      resource_id: "resource123",
      resource_link_id: option.None,
      tag: option.None,
      start_date_time: option.None,
      end_date_time: option.None,
      grades_released: option.None,
    ),
    fixture_access_token(),
  )
  |> should.be_ok()
}

pub fn delete_line_item_test() {
  let expect_http_delete = fn(req: request.Request(String)) {
    req.method
    |> should.equal(http.Delete)

    req.path
    |> should.equal("/context/2923/lineitems/1")

    response.new(204)
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_delete)

  ags.delete_line_item(
    http_provider,
    "https://lms.example.com/context/2923/lineitems/1",
    fixture_access_token(),
  )
  |> should.equal(Ok(Nil))
}

pub fn list_results_test() {
  let expect_http_get = fn(req: request.Request(String)) {
    req.method
    |> should.equal(http.Get)

    req.path
    |> should.equal("/context/2923/lineitems/1/results")

    req.query
    |> option.unwrap("")
    |> string.contains("resource_link_id=abc")
    |> should.equal(True)

    req.query
    |> option.unwrap("")
    |> string.contains("user_id=user123")
    |> should.equal(True)

    req.query
    |> option.unwrap("")
    |> string.contains("limit=10")
    |> should.equal(True)

    req
    |> request.get_header("accept")
    |> should.equal(Ok("application/vnd.ims.lis.v2.resultcontainer+json"))

    response.new(200)
    |> response.set_body(
      "[{\"id\":\"r1\",\"userId\":\"user123\",\"resultScore\":1.0,\"resultMaximum\":2.0,\"comment\":\"Great\",\"scoreOf\":\"https://lms.example.com/context/2923/lineitems/1\"}]",
    )
    |> Ok
  }

  let query =
    ags.ResultsQuery(user_id: option.Some("user123"), limit: option.Some(10))

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  ags.list_results(
    http_provider,
    "https://lms.example.com/context/2923/lineitems/1?resource_link_id=abc",
    query,
    fixture_access_token(),
  )
  |> should.equal(
    Ok(ags.Paged(
      items: [
        ags_result.Result(
          id: option.Some("r1"),
          user_id: "user123",
          result_score: option.Some(1.0),
          result_maximum: option.Some(2.0),
          comment: option.Some("Great"),
          score_of: option.Some(
            "https://lms.example.com/context/2923/lineitems/1",
          ),
        ),
      ],
      links: PageLinks(
        next: option.None,
        prev: option.None,
        first: option.None,
        last: option.None,
      ),
    )),
  )
}

pub fn invalid_line_item_payload_test() {
  let expect_http_get = fn(_req: request.Request(String)) {
    response.new(200)
    |> response.set_body("{\"invalid\":true}")
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  let result =
    ags.get_line_item(
      http_provider,
      "https://lms.example.com/context/2923/lineitems/1",
      fixture_access_token(),
    )

  case result {
    Error(ags.DecodeLineItem(_)) -> True |> should.equal(True)
    _ -> False |> should.equal(True)
  }
}

pub fn invalid_result_payload_test() {
  let expect_http_get = fn(_req: request.Request(String)) {
    response.new(200)
    |> response.set_body("[{\"invalid\":true}]")
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  let result =
    ags.list_results(
      http_provider,
      "https://lms.example.com/context/2923/lineitems/1",
      ags.default_results_query(),
      fixture_access_token(),
    )

  case result {
    Error(ags.DecodeResult(_)) -> True |> should.equal(True)
    _ -> False |> should.equal(True)
  }
}

pub fn missing_scope_guard_test() {
  let claims = ags_claim([ags.result_readonly_scope_url])

  ags.require_can_post_scores(claims)
  |> should.equal(Error(ags.ScopeInsufficient(ags.scores_scope_url)))
}

pub fn scope_helpers_test() {
  let claims =
    ags_claim([
      ags.lineitem_readonly_scope_url,
      ags.result_readonly_scope_url,
      ags.scores_scope_url,
    ])

  ags.can_read_line_items(claims)
  |> should.equal(True)

  ags.can_post_scores(claims)
  |> should.equal(True)

  ags.can_read_results(claims)
  |> should.equal(True)

  ags.can_write_line_items(claims)
  |> should.equal(False)

  ags.grade_passback_available(claims)
  |> should.equal(True)
}

pub fn malformed_link_header_fallback_test() {
  let expect_http_get = fn(_req: request.Request(String)) {
    response.new(200)
    |> response.set_header("link", "broken-link-header")
    |> response.set_body("[]")
    |> Ok
  }

  let http_provider = http_mock_provider.http_provider(expect_http_get)

  ags.list_line_items(
    http_provider,
    "https://lms.example.com/context/2923/lineitems",
    ags.default_line_items_query(),
    fixture_access_token(),
  )
  |> should.equal(
    Ok(ags.Paged(
      items: [],
      links: PageLinks(
        next: option.None,
        prev: option.None,
        first: option.None,
        last: option.None,
      ),
    )),
  )
}

fn fixture_access_token() -> AccessToken {
  AccessToken(
    token: "SOME_ACCESS_TOKEN",
    token_type: "Bearer",
    expires_in: 3600,
    scope: "some scopes",
  )
}

fn fixture_score() -> Score {
  Score(
    score_given: 1.0,
    score_maximum: 2.0,
    timestamp: "2023-10-01T00:00:00Z",
    user_id: "user123",
    comment: "Great job!",
    activity_progress: "Completed",
    grading_progress: "FullyGraded",
  )
}

fn fixture_line_item(line_item_id: String) -> LineItem {
  LineItem(
    id: option.Some(line_item_id),
    score_maximum: 2.0,
    label: "Test Line Item",
    resource_id: "resource123",
    resource_link_id: option.None,
    tag: option.None,
    start_date_time: option.None,
    end_date_time: option.None,
    grades_released: option.None,
  )
}

fn ags_claim(scopes: List(String)) -> dict.Dict(String, dynamic.Dynamic) {
  dict.from_list([
    #(
      ags.lti_ags_claim_url,
      dynamic.properties([
        #(
          dynamic.string("lineitem"),
          dynamic.string("https://lms.example.com/context/2923/lineitems/1"),
        ),
        #(
          dynamic.string("lineitems"),
          dynamic.string("https://lms.example.com/context/2923/lineitems"),
        ),
        #(
          dynamic.string("scope"),
          dynamic.list(list.map(scopes, dynamic.string)),
        ),
        #(dynamic.string("errors"), dynamic.properties([])),
      ]),
    ),
  ])
}
