import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import lightbulb/http/link_header
import lightbulb/providers/http_provider.{type HttpProvider}
import lightbulb/services/access_token.{
  type AccessToken, set_authorization_header,
}
import lightbulb/services/ags/line_item.{type LineItem, LineItem}
import lightbulb/services/ags/result as ags_result
import lightbulb/services/ags/score.{type Score}
import lightbulb/utils/logger

pub const lti_ags_claim_url = "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint"

pub const lineitem_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"

pub const lineitem_readonly_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem.readonly"

pub const result_readonly_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly"

pub const scores_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/score"

pub type AgsError {
  RequestInvalidUrl(url: String)
  HttpTransport(reason: String)
  HttpUnexpectedStatus(status: Int, body: String)
  DecodeLineItem(reason: String)
  DecodeResult(reason: String)
  ScopeInsufficient(required_scope: String)
  PaginationInvalidLinkHeader(reason: String)
  InvalidLineItemId
}

pub type LineItemsQuery {
  LineItemsQuery(
    resource_link_id: Option(String),
    resource_id: Option(String),
    tag: Option(String),
    limit: Option(Int),
  )
}

pub type ResultsQuery {
  ResultsQuery(user_id: Option(String), limit: Option(Int))
}

pub type Paged(a) {
  Paged(items: List(a), links: link_header.PageLinks)
}

/// Returns an empty AGS line-items query with no filters.
pub fn default_line_items_query() -> LineItemsQuery {
  LineItemsQuery(
    resource_link_id: None,
    resource_id: None,
    tag: None,
    limit: None,
  )
}

/// Returns an empty AGS results query with no filters.
pub fn default_results_query() -> ResultsQuery {
  ResultsQuery(user_id: None, limit: None)
}

/// Converts AGS service errors to stable human-readable messages.
pub fn ags_error_to_string(error: AgsError) -> String {
  case error {
    RequestInvalidUrl(url) -> "invalid AGS URL: " <> url
    HttpTransport(reason) -> "AGS transport error: " <> reason
    HttpUnexpectedStatus(status, _) ->
      "unexpected AGS HTTP status: " <> int.to_string(status)
    DecodeLineItem(reason) -> "failed to decode line item payload: " <> reason
    DecodeResult(reason) -> "failed to decode result payload: " <> reason
    ScopeInsufficient(required_scope) ->
      "launch does not include required AGS scope: " <> required_scope
    PaginationInvalidLinkHeader(reason) ->
      "invalid pagination Link header: " <> reason
    InvalidLineItemId -> "line item id is required"
  }
}

/// Posts a score to the AGS `scores` endpoint for a line item.
pub fn post_score(
  http_provider: HttpProvider,
  score: Score,
  line_item: LineItem,
  access_token: AccessToken,
) -> Result(String, AgsError) {
  let LineItem(id: id, ..) = line_item

  use line_item_id <- result.try(id |> option.to_result(InvalidLineItemId))

  let url = build_url_with_path(line_item_id, "scores")
  let body = score.to_json(score) |> json.to_string()

  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) { RequestInvalidUrl(url) }),
  )

  let req =
    req
    |> set_score_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Post)
    |> request.set_body(body)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 | 202 | 204 -> Ok(res.body)
        _ -> Error(HttpUnexpectedStatus(res.status, res.body))
      }

    Error(reason) -> Error(HttpTransport(string.inspect(reason)))
  }
}

/// Creates a new AGS line item under the line-items container URL.
pub fn create_line_item(
  http_provider: HttpProvider,
  line_items_service_url: String,
  resource_id: String,
  score_maximum: Float,
  label: String,
  access_token: AccessToken,
) -> Result(LineItem, AgsError) {
  let line_item =
    LineItem(
      id: None,
      score_maximum: score_maximum,
      label: label,
      resource_id: resource_id,
      resource_link_id: None,
      tag: None,
      start_date_time: None,
      end_date_time: None,
      grades_released: None,
    )

  let body = line_item.to_json(line_item) |> json.to_string()

  use req <- result.try(
    request.to(line_items_service_url)
    |> result.map_error(fn(_) { RequestInvalidUrl(line_items_service_url) }),
  )

  let req =
    req
    |> set_line_item_write_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Post)
    |> request.set_body(body)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 ->
          json.parse(res.body, line_item.decoder())
          |> result.map_error(fn(e) { DecodeLineItem(string.inspect(e)) })

        _ -> Error(HttpUnexpectedStatus(res.status, res.body))
      }

    Error(reason) -> Error(HttpTransport(string.inspect(reason)))
  }
}

/// Fetches the first matching line item for `resource_id` or creates one.
pub fn fetch_or_create_line_item(
  http_provider: HttpProvider,
  line_items_service_url: String,
  resource_id: String,
  maximum_score_provider: fn() -> Float,
  label: String,
  access_token: AccessToken,
) -> Result(LineItem, AgsError) {
  let query =
    LineItemsQuery(
      ..default_line_items_query(),
      resource_id: Some(resource_id),
      limit: Some(1),
    )

  use page <- result.try(list_line_items(
    http_provider,
    line_items_service_url,
    query,
    access_token,
  ))

  let Paged(items: items, ..) = page

  case items {
    [] ->
      create_line_item(
        http_provider,
        line_items_service_url,
        resource_id,
        maximum_score_provider(),
        label,
        access_token,
      )

    [raw_line_item, ..] -> Ok(raw_line_item)
  }
}

/// Fetches a single line item by its absolute line-item URL.
pub fn get_line_item(
  http_provider: HttpProvider,
  line_item_url: String,
  access_token: AccessToken,
) -> Result(LineItem, AgsError) {
  use req <- result.try(
    request.to(line_item_url)
    |> result.map_error(fn(_) { RequestInvalidUrl(line_item_url) }),
  )

  let req =
    req
    |> set_line_item_read_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Get)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 ->
          json.parse(res.body, line_item.decoder())
          |> result.map_error(fn(e) { DecodeLineItem(string.inspect(e)) })
        _ -> Error(HttpUnexpectedStatus(res.status, res.body))
      }

    Error(reason) -> Error(HttpTransport(string.inspect(reason)))
  }
}

/// Lists line items from AGS, applying query filters and pagination links.
pub fn list_line_items(
  http_provider: HttpProvider,
  line_items_service_url: String,
  query: LineItemsQuery,
  access_token: AccessToken,
) -> Result(Paged(LineItem), AgsError) {
  let url =
    build_url_with_params(
      line_items_service_url,
      line_items_query_params(query),
    )

  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) { RequestInvalidUrl(url) }),
  )

  let req =
    req
    |> set_line_items_list_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Get)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 -> {
          use items <- result.try(
            json.parse(res.body, decode.list(line_item.decoder()))
            |> result.map_error(fn(e) { DecodeLineItem(string.inspect(e)) }),
          )

          let links = page_links_from_response(res)

          Ok(Paged(items: items, links: links))
        }

        _ -> Error(HttpUnexpectedStatus(res.status, res.body))
      }

    Error(reason) -> Error(HttpTransport(string.inspect(reason)))
  }
}

/// Replaces an existing line item identified by `line_item.id`.
pub fn update_line_item(
  http_provider: HttpProvider,
  line_item: LineItem,
  access_token: AccessToken,
) -> Result(LineItem, AgsError) {
  let LineItem(id: id, ..) = line_item

  use line_item_url <- result.try(id |> option.to_result(InvalidLineItemId))

  use req <- result.try(
    request.to(line_item_url)
    |> result.map_error(fn(_) { RequestInvalidUrl(line_item_url) }),
  )

  let req =
    req
    |> set_line_item_write_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Put)
    |> request.set_body(line_item.to_json(line_item) |> json.to_string())

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 ->
          json.parse(res.body, line_item.decoder())
          |> result.map_error(fn(e) { DecodeLineItem(string.inspect(e)) })

        _ -> Error(HttpUnexpectedStatus(res.status, res.body))
      }

    Error(reason) -> Error(HttpTransport(string.inspect(reason)))
  }
}

/// Deletes a line item by URL.
pub fn delete_line_item(
  http_provider: HttpProvider,
  line_item_url: String,
  access_token: AccessToken,
) -> Result(Nil, AgsError) {
  use req <- result.try(
    request.to(line_item_url)
    |> result.map_error(fn(_) { RequestInvalidUrl(line_item_url) }),
  )

  let req =
    req
    |> set_authorization_header(access_token)
    |> request.set_method(http.Delete)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 204 -> Ok(Nil)
        _ -> Error(HttpUnexpectedStatus(res.status, res.body))
      }

    Error(reason) -> Error(HttpTransport(string.inspect(reason)))
  }
}

/// Lists result records for a line item.
pub fn list_results(
  http_provider: HttpProvider,
  line_item_url: String,
  query: ResultsQuery,
  access_token: AccessToken,
) -> Result(Paged(ags_result.Result), AgsError) {
  let url =
    build_url_with_path(line_item_url, "results")
    |> build_url_with_params(results_query_params(query))

  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) { RequestInvalidUrl(url) }),
  )

  let req =
    req
    |> set_results_list_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Get)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 -> {
          use items <- result.try(
            json.parse(res.body, decode.list(ags_result.decoder()))
            |> result.map_error(fn(e) { DecodeResult(string.inspect(e)) }),
          )

          let links = page_links_from_response(res)

          Ok(Paged(items: items, links: links))
        }

        _ -> Error(HttpUnexpectedStatus(res.status, res.body))
      }

    Error(reason) -> Error(HttpTransport(string.inspect(reason)))
  }
}

/// Given a set of LTI claims, returns True if score posting is available.
pub fn grade_passback_available(
  lti_launch_claims: Dict(String, Dynamic),
) -> Bool {
  can_post_scores(lti_launch_claims)
}

/// Returns True when the launch grants read access to line items.
pub fn can_read_line_items(lti_launch_claims: Dict(String, Dynamic)) -> Bool {
  case get_lti_ags_claim(lti_launch_claims) {
    Ok(claim) ->
      list.contains(claim.scope, lineitem_scope_url)
      || list.contains(claim.scope, lineitem_readonly_scope_url)

    Error(_) -> False
  }
}

/// Returns True when the launch grants write access to line items.
pub fn can_write_line_items(lti_launch_claims: Dict(String, Dynamic)) -> Bool {
  case get_lti_ags_claim(lti_launch_claims) {
    Ok(claim) -> list.contains(claim.scope, lineitem_scope_url)
    Error(_) -> False
  }
}

/// Returns True when the launch grants score-posting access.
pub fn can_post_scores(lti_launch_claims: Dict(String, Dynamic)) -> Bool {
  case get_lti_ags_claim(lti_launch_claims) {
    Ok(claim) -> list.contains(claim.scope, scores_scope_url)
    Error(_) -> False
  }
}

/// Returns True when the launch grants read access to result records.
pub fn can_read_results(lti_launch_claims: Dict(String, Dynamic)) -> Bool {
  case get_lti_ags_claim(lti_launch_claims) {
    Ok(claim) -> list.contains(claim.scope, result_readonly_scope_url)
    Error(_) -> False
  }
}

/// Ensures line-item read scope is present.
pub fn require_can_read_line_items(
  lti_launch_claims: Dict(String, Dynamic),
) -> Result(Nil, AgsError) {
  use <- bool.guard(
    when: !can_read_line_items(lti_launch_claims),
    return: Error(ScopeInsufficient(
      lineitem_scope_url <> " or " <> lineitem_readonly_scope_url,
    )),
  )

  Ok(Nil)
}

/// Ensures line-item write scope is present.
pub fn require_can_write_line_items(
  lti_launch_claims: Dict(String, Dynamic),
) -> Result(Nil, AgsError) {
  use <- bool.guard(
    when: !can_write_line_items(lti_launch_claims),
    return: Error(ScopeInsufficient(lineitem_scope_url)),
  )

  Ok(Nil)
}

/// Ensures score-posting scope is present.
pub fn require_can_post_scores(
  lti_launch_claims: Dict(String, Dynamic),
) -> Result(Nil, AgsError) {
  use <- bool.guard(
    when: !can_post_scores(lti_launch_claims),
    return: Error(ScopeInsufficient(scores_scope_url)),
  )

  Ok(Nil)
}

/// Ensures result-read scope is present.
pub fn require_can_read_results(
  lti_launch_claims: Dict(String, Dynamic),
) -> Result(Nil, AgsError) {
  use <- bool.guard(
    when: !can_read_results(lti_launch_claims),
    return: Error(ScopeInsufficient(result_readonly_scope_url)),
  )

  Ok(Nil)
}

/// Returns the AGS line-items service URL from launch claims.
pub fn get_line_items_service_url(
  lti_launch_claims: Dict(String, Dynamic),
) -> Result(String, String) {
  {
    use lti_ags_claim <- result.try(get_lti_ags_claim(lti_launch_claims))

    lti_ags_claim.lineitems
    |> option.to_result("Missing line items URL in LTI AGS claim")
  }
}

pub type AgsClaim {
  AgsClaim(
    lineitem: Option(String),
    lineitems: Option(String),
    scope: List(String),
    errors: Dict(String, Dynamic),
    validation_context: Option(Dynamic),
  )
}

/// Decodes the AGS claim from LTI launch claims.
pub fn get_lti_ags_claim(
  claims: Dict(String, Dynamic),
) -> Result(AgsClaim, String) {
  let lti_ags_claim_decoder = {
    use lineitem <- decode.optional_field(
      "lineitem",
      None,
      decode.optional(decode.string),
    )

    use lineitems <- decode.optional_field(
      "lineitems",
      None,
      decode.optional(decode.string),
    )

    use scope <- decode.field("scope", decode.list(decode.string))

    use errors <- decode.optional_field(
      "errors",
      dict.new(),
      decode.dict(decode.string, decode.dynamic),
    )

    use validation_context <- decode.optional_field(
      "validation_context",
      None,
      decode.optional(decode.dynamic),
    )

    decode.success(AgsClaim(
      lineitem: lineitem,
      lineitems: lineitems,
      scope: scope,
      errors: errors,
      validation_context: validation_context,
    ))
  }

  dict.get(claims, lti_ags_claim_url)
  |> result.replace_error("Missing LTI AGS claim")
  |> result.try(fn(c) {
    decode.run(c, lti_ags_claim_decoder)
    |> result.replace_error("Invalid LTI AGS claim")
  })
}

fn set_line_items_list_headers(
  req: request.Request(String),
) -> request.Request(String) {
  req
  |> request.set_header(
    "Accept",
    "application/vnd.ims.lis.v2.lineitemcontainer+json",
  )
}

fn set_line_item_read_headers(
  req: request.Request(String),
) -> request.Request(String) {
  req
  |> request.set_header("Accept", "application/vnd.ims.lis.v2.lineitem+json")
}

fn set_line_item_write_headers(
  req: request.Request(String),
) -> request.Request(String) {
  req
  |> request.set_header(
    "Content-Type",
    "application/vnd.ims.lis.v2.lineitem+json",
  )
  |> request.set_header("Accept", "application/vnd.ims.lis.v2.lineitem+json")
}

fn set_score_headers(req: request.Request(String)) -> request.Request(String) {
  req
  |> request.set_header("Content-Type", "application/vnd.ims.lis.v1.score+json")
  |> request.set_header("Accept", "application/json")
}

fn set_results_list_headers(
  req: request.Request(String),
) -> request.Request(String) {
  req
  |> request.set_header(
    "Accept",
    "application/vnd.ims.lis.v2.resultcontainer+json",
  )
}

fn build_url_with_path(base: String, path: String) -> String {
  case string.split(base, "?") {
    [base_path, query] ->
      base_path
      <> "/"
      <> path
      <> case query {
        "" -> ""
        _ -> "?" <> query
      }

    _ -> base <> "/" <> path
  }
}

fn build_url_with_params(
  base: String,
  params: List(#(String, String)),
) -> String {
  case params {
    [] -> base
    _ -> {
      case string.split(base, "?") {
        [base_path, query] -> {
          let existing_params = case uri.parse_query(query) {
            Ok(parsed) -> parsed
            Error(_) -> []
          }

          base_path
          <> "?"
          <> uri.query_to_string(list.append(existing_params, params))
        }

        _ -> base <> "?" <> uri.query_to_string(params)
      }
    }
  }
}

fn line_items_query_params(query: LineItemsQuery) -> List(#(String, String)) {
  let LineItemsQuery(resource_link_id, resource_id, tag, limit) = query

  []
  |> add_query_param("resource_link_id", resource_link_id)
  |> add_query_param("resource_id", resource_id)
  |> add_query_param("tag", tag)
  |> add_query_param("limit", limit |> option.map(int.to_string))
}

fn results_query_params(query: ResultsQuery) -> List(#(String, String)) {
  let ResultsQuery(user_id, limit) = query

  []
  |> add_query_param("user_id", user_id)
  |> add_query_param("limit", limit |> option.map(int.to_string))
}

fn add_query_param(
  params: List(#(String, String)),
  key: String,
  value: Option(String),
) -> List(#(String, String)) {
  case value {
    Some(v) -> [#(key, v), ..params]
    None -> params
  }
}

fn page_links_from_response(
  resp: response.Response(String),
) -> link_header.PageLinks {
  case response.get_header(resp, "link") {
    Ok(link) ->
      case link_header.parse(link) {
        Ok(links) -> links
        Error(error) -> {
          let reason = link_header.link_header_error_to_string(error)
          logger.warn(ags_error_to_string(PaginationInvalidLinkHeader(reason)))
          link_header.empty_page_links()
        }
      }

    Error(_) -> link_header.empty_page_links()
  }
}
