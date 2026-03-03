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
import lightbulb/services/nrps/membership.{type Membership}
import lightbulb/utils/logger

pub const nrps_claim_url = "https://purl.imsglobal.org/spec/lti-nrps/claim/namesroleservice"

pub const context_membership_readonly_claim_url = "https://purl.imsglobal.org/spec/lti-nrps/scope/contextmembership.readonly"

pub type NrpsError {
  ClaimMissing
  ClaimInvalid
  ScopeInsufficient(required_scope: String)
  RequestInvalidUrl(url: String)
  HttpTransport(reason: String)
  HttpUnexpectedStatus(status: Int, body: String)
  DecodeMembershipContainer(reason: String)
  DecodeMember(reason: String)
  PaginationInvalidLinkHeader(reason: String)
}

pub type NrpsClaim {
  NrpsClaim(context_memberships_url: String, service_versions: List(String))
}

pub type MembershipsQuery {
  MembershipsQuery(
    role: Option(String),
    limit: Option(Int),
    rlid: Option(String),
    url: Option(String),
  )
}

pub type MembershipsPage {
  MembershipsPage(members: List(Membership), links: link_header.PageLinks)
}

/// Returns an empty NRPS memberships query with no filters.
pub fn default_memberships_query() -> MembershipsQuery {
  MembershipsQuery(role: None, limit: None, rlid: None, url: None)
}

/// Converts NRPS service errors to stable human-readable messages.
pub fn nrps_error_to_string(error: NrpsError) -> String {
  case error {
    ClaimMissing -> "missing LTI NRPS claim"
    ClaimInvalid -> "invalid LTI NRPS claim"
    ScopeInsufficient(required_scope) ->
      "launch does not include required NRPS scope: " <> required_scope
    RequestInvalidUrl(url) -> "invalid NRPS URL: " <> url
    HttpTransport(reason) -> "NRPS transport error: " <> reason
    HttpUnexpectedStatus(status, _) ->
      "unexpected NRPS HTTP status: " <> int.to_string(status)
    DecodeMembershipContainer(reason) ->
      "failed to decode NRPS membership container: " <> reason
    DecodeMember(reason) -> "failed to decode NRPS member: " <> reason
    PaginationInvalidLinkHeader(reason) ->
      "invalid pagination Link header: " <> reason
  }
}

/// Fetches memberships from the NRPS service.
pub fn fetch_memberships(
  http_provider: HttpProvider,
  context_memberships_url: String,
  access_token: AccessToken,
) -> Result(List(Membership), NrpsError) {
  fetch_memberships_with_options(
    http_provider,
    context_memberships_url,
    default_memberships_query(),
    access_token,
  )
  |> result.map(fn(page) {
    let MembershipsPage(members: members, ..) = page
    members
  })
}

/// Fetches memberships using query options and returns page links.
pub fn fetch_memberships_with_options(
  http_provider: HttpProvider,
  context_memberships_url: String,
  query: MembershipsQuery,
  access_token: AccessToken,
) -> Result(MembershipsPage, NrpsError) {
  let url = resolve_memberships_url(context_memberships_url, query)
  logger.info("Fetching memberships from " <> url)

  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) { RequestInvalidUrl(url) }),
  )

  let req =
    req
    |> set_membership_headers()
    |> set_authorization_header(access_token)
    |> request.set_method(http.Get)

  case http_provider.send(req) {
    Ok(res) ->
      case res.status {
        200 | 201 -> {
          use members <- result.try(members_from_response(res.body))
          let links = page_links_from_response(res)
          Ok(MembershipsPage(members: members, links: links))
        }
        _ -> Error(HttpUnexpectedStatus(res.status, res.body))
      }

    Error(reason) -> Error(HttpTransport(string.inspect(reason)))
  }
}

/// Fetches the next page of memberships from a pagination URL.
pub fn fetch_next_memberships_page(
  http_provider: HttpProvider,
  next_url: String,
  access_token: AccessToken,
) -> Result(MembershipsPage, NrpsError) {
  fetch_memberships_with_options(
    http_provider,
    next_url,
    MembershipsQuery(..default_memberships_query(), url: Some(next_url)),
    access_token,
  )
}

/// Fetches the differences page of memberships from a pagination URL.
pub fn fetch_differences_memberships_page(
  http_provider: HttpProvider,
  differences_url: String,
  access_token: AccessToken,
) -> Result(MembershipsPage, NrpsError) {
  fetch_memberships_with_options(
    http_provider,
    differences_url,
    MembershipsQuery(..default_memberships_query(), url: Some(differences_url)),
    access_token,
  )
}

/// Returns True if the NRPS service and readonly scope are available.
pub fn nrps_available(lti_launch_claims: Dict(String, Dynamic)) -> Bool {
  can_read_memberships(lti_launch_claims)
}

/// Returns True when the NRPS claim exists and readonly scope is present.
pub fn can_read_memberships(lti_launch_claims: Dict(String, Dynamic)) -> Bool {
  case get_nrps_claim_with_scope(lti_launch_claims) {
    Ok(#(_claim, scope)) ->
      list.contains(scope, context_membership_readonly_claim_url)

    Error(_) -> False
  }
}

/// Ensures the readonly NRPS scope is present.
pub fn require_can_read_memberships(
  lti_launch_claims: Dict(String, Dynamic),
) -> Result(Nil, NrpsError) {
  use <- bool.guard(
    when: !can_read_memberships(lti_launch_claims),
    return: Error(ScopeInsufficient(context_membership_readonly_claim_url)),
  )

  Ok(Nil)
}

/// Returns the context memberships URL from the LTI launch claims.
pub fn get_membership_service_url(
  lti_launch_claims: Dict(String, Dynamic),
) -> Result(String, NrpsError) {
  get_nrps_claim(lti_launch_claims)
  |> result.map(fn(nrps_claim) { nrps_claim.context_memberships_url })
}

/// Decodes the NRPS claim from launch claims.
pub fn get_nrps_claim(
  claims: Dict(String, Dynamic),
) -> Result(NrpsClaim, NrpsError) {
  get_nrps_claim_with_scope(claims)
  |> result.map(fn(tuple) {
    let #(claim, _scope) = tuple
    claim
  })
}

fn get_nrps_claim_with_scope(
  claims: Dict(String, Dynamic),
) -> Result(#(NrpsClaim, List(String)), NrpsError) {
  let nrps_claim_decoder = {
    use context_memberships_url <- decode.field(
      "context_memberships_url",
      decode.string,
    )
    use service_versions <- decode.field(
      "service_versions",
      decode.list(decode.string),
    )
    use scope <- decode.optional_field("scope", [], decode.list(decode.string))

    decode.success(#(
      NrpsClaim(
        context_memberships_url: context_memberships_url,
        service_versions: service_versions,
      ),
      scope,
    ))
  }

  dict.get(claims, nrps_claim_url)
  |> result.map_error(fn(_) { ClaimMissing })
  |> result.try(fn(c) {
    decode.run(c, nrps_claim_decoder)
    |> result.map_error(fn(_) { ClaimInvalid })
  })
}

fn set_membership_headers(
  req: request.Request(String),
) -> request.Request(String) {
  req
  |> request.set_header(
    "Accept",
    "application/vnd.ims.lti-nrps.v2.membershipcontainer+json",
  )
}

fn resolve_memberships_url(base: String, query: MembershipsQuery) -> String {
  let MembershipsQuery(url: url, ..) = query

  case url {
    Some(override) -> override
    None -> build_url_with_params(base, query_params(query))
  }
}

fn query_params(query: MembershipsQuery) -> List(#(String, String)) {
  let MembershipsQuery(role, limit, rlid, _) = query
  let string_limit = case limit {
    Some(value) -> Some(int.to_string(value))
    None -> None
  }

  []
  |> add_query_param("role", role)
  |> add_query_param("limit", string_limit)
  |> add_query_param("rlid", rlid)
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

fn members_from_response(body: String) -> Result(List(Membership), NrpsError) {
  let members_decoder = {
    use members <- decode.field("members", decode.list(decode.dynamic))
    decode.success(members)
  }

  use raw_members <- result.try(
    json.parse(body, members_decoder)
    |> result.map_error(fn(e) { DecodeMembershipContainer(string.inspect(e)) }),
  )

  decode_members(raw_members, [])
}

fn decode_members(
  raw_members: List(Dynamic),
  acc: List(Membership),
) -> Result(List(Membership), NrpsError) {
  case raw_members {
    [] -> Ok(list.reverse(acc))
    [raw, ..rest] -> {
      use member <- result.try(
        decode.run(raw, membership.decoder())
        |> result.map_error(fn(e) { DecodeMember(string.inspect(e)) }),
      )
      decode_members(rest, [member, ..acc])
    }
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
          logger.warn(nrps_error_to_string(PaginationInvalidLinkHeader(reason)))
          link_header.empty_page_links()
        }
      }

    Error(_) -> link_header.empty_page_links()
  }
}
