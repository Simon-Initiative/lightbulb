import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request.{type Request}
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/result
import gleam/string
import gleam/uri
import lightbulb/providers/http_provider.{type HttpProvider}
import lightbulb/services/access_token.{
  type AccessToken, set_authorization_header,
}
import lightbulb/services/ags/line_item.{type LineItem, LineItem}
import lightbulb/services/ags/score.{type Score}
import lightbulb/utils/logger

pub const lti_ags_claim_url = "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint"

pub const lineitem_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/lineitem"

pub const result_readonly_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/result.readonly"

pub const scores_scope_url = "https://purl.imsglobal.org/spec/lti-ags/scope/score"

/// Posts a score to the AGS service for a given line item.
pub fn post_score(
  http_provider: HttpProvider,
  score: Score,
  line_item: LineItem,
  access_token: AccessToken,
) -> Result(String, String) {
  use line_item_id <- result.try(
    line_item.id |> option.to_result("Missing line item ID"),
  )
  let url = build_url_with_path(line_item_id, "scores")
  let body =
    score.to_json(score)
    |> json.to_string()

  use req <- result.try(
    request.to(url)
    |> result.replace_error("Error creating request for URL " <> url),
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
        200 | 201 | 204 -> Ok(res.body)
        _ -> Error("Unexpected status: " <> string.inspect(res))
      }

    e -> Error("Error posting score: " <> string.inspect(e))
  }
}

/// Fetches an existing line item or creates a new one if it doesn't exist.
pub fn fetch_or_create_line_item(
  http_provider: HttpProvider,
  line_items_service_url: String,
  resource_id: String,
  maximum_score_provider: fn() -> Float,
  label: String,
  access_token: AccessToken,
) -> Result(LineItem, String) {
  let url =
    build_url_with_params(line_items_service_url, [
      #("resource_id", resource_id),
      #("limit", "1"),
    ])

  use req <- result.try(
    request.to(url)
    |> result.replace_error("Error creating request for URL " <> url),
  )

  let req =
    req
    |> set_line_items_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Get)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 -> {
          use line_items <- result.try(
            json.parse(res.body, decode.list(line_item.decoder()))
            |> result.map_error(fn(e) {
              logger.error_meta("Error decoding line items", e)
              "Error decoding line items"
            }),
          )

          case line_items {
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

        _ -> Error("Error retrieving existing line items")
      }

    _ -> Error("Error retrieving existing line items")
  }
}

/// Creates a new line item.
pub fn create_line_item(
  http_provider: HttpProvider,
  line_items_service_url: String,
  resource_id: String,
  score_maximum: Float,
  label: String,
  access_token: AccessToken,
) -> Result(LineItem, String) {
  let line_item =
    LineItem(
      id: None,
      score_maximum: score_maximum,
      label: label,
      resource_id: resource_id,
    )

  let body =
    line_item.to_json(line_item)
    |> json.to_string()

  use req <- result.try(
    request.to(line_items_service_url)
    |> result.replace_error(
      "Error creating request for URL " <> line_items_service_url,
    ),
  )

  let req =
    req
    |> set_line_items_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Post)
    |> request.set_body(body)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 -> {
          json.parse(res.body, line_item.decoder())
          |> result.map_error(fn(e) {
            "Error decoding line item: " <> string.inspect(e)
          })
        }
        e -> {
          logger.error_meta("Error creating line item", res)
          Error("Unexpected status: " <> string.inspect(e))
        }
      }

    e -> {
      logger.error_meta("Error creating line item", e)
      Error("Error creating new line item")
    }
  }
}

/// Given a set of LTI claims, returns True if the grade passback
/// feature is available for the given LTI launch.
pub fn grade_passback_available(
  lti_launch_claims: Dict(String, Dynamic),
) -> Bool {
  {
    use lti_ags_claim <- result.try(
      get_lti_ags_claim(lti_launch_claims) |> result.replace_error(False),
    )

    Ok(list.contains(lti_ags_claim.scope, result_readonly_scope_url))
  }
  |> result.unwrap_both()
}

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
  |> result.then(fn(c) {
    decode.run(c, lti_ags_claim_decoder)
    |> result.replace_error("Invalid LTI AGS claim")
  })
}

fn set_line_items_headers(req: Request(String)) -> Request(String) {
  req
  |> request.set_header(
    "Content-Type",
    "application/vnd.ims.lis.v2.lineitem+json",
  )
  |> request.set_header(
    "Accept",
    "application/vnd.ims.lis.v2.lineitemcontainer+json",
  )
}

fn set_score_headers(req: Request(String)) -> Request(String) {
  req
  |> request.set_header("Content-Type", "application/vnd.ims.lis.v1.score+json")
  |> request.set_header(
    "Accept",
    "application/vnd.ims.lis.v2.lineitemcontainer+json",
  )
}

fn build_url_with_path(base: String, path: String) -> String {
  case string.split(base, "?") {
    [base, query] -> base <> "/" <> path <> "?" <> query
    _ -> base <> "/" <> path
  }
}

fn build_url_with_params(
  base: String,
  params: List(#(String, String)),
) -> String {
  case uri.parse_query(base) {
    Ok(base_params) ->
      base <> "?" <> uri.query_to_string(list.append(base_params, params))
    _ -> base <> "?" <> uri.query_to_string(params)
  }
}
