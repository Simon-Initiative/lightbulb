import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type LinkHeaderError {
  InvalidLinkHeader(reason: String)
}

pub type PageLinks {
  PageLinks(
    next: Option(String),
    differences: Option(String),
    prev: Option(String),
    first: Option(String),
    last: Option(String),
  )
}

pub fn empty_page_links() -> PageLinks {
  PageLinks(next: None, differences: None, prev: None, first: None, last: None)
}

pub fn parse(header: String) -> Result(PageLinks, LinkHeaderError) {
  parse_segments(string.split(header, ","), empty_page_links())
}

pub fn link_header_error_to_string(error: LinkHeaderError) -> String {
  case error {
    InvalidLinkHeader(reason) -> reason
  }
}

fn parse_segments(
  segments: List(String),
  acc: PageLinks,
) -> Result(PageLinks, LinkHeaderError) {
  case segments {
    [] -> Ok(acc)
    [segment, ..rest] -> {
      use parsed <- result.try(parse_link_segment(segment))
      parse_segments(rest, merge_links(acc, parsed))
    }
  }
}

fn parse_link_segment(segment: String) -> Result(PageLinks, LinkHeaderError) {
  let trimmed = string.trim(segment)
  let parts = string.split(trimmed, ";")

  case parts {
    [url_part, ..params] -> {
      use url <- result.try(extract_url(url_part))
      use relations <- result.try(extract_relations(params))

      Ok(assign_relations(url, relations, empty_page_links()))
    }
    _ -> Error(InvalidLinkHeader("missing link segment"))
  }
}

fn extract_url(raw: String) -> Result(String, LinkHeaderError) {
  let trimmed = string.trim(raw)

  use <- bool.guard(
    when: !string.starts_with(trimmed, "<") || !string.ends_with(trimmed, ">"),
    return: Error(InvalidLinkHeader("link URL is not wrapped in angle brackets")),
  )

  Ok(
    trimmed
    |> string.drop_start(1)
    |> string.drop_end(1),
  )
}

fn extract_relations(
  params: List(String),
) -> Result(List(String), LinkHeaderError) {
  let rel_params =
    params
    |> list.filter(fn(param) {
      string.trim(param)
      |> string.starts_with("rel=")
    })

  case rel_params {
    [] -> Error(InvalidLinkHeader("link relation is missing"))
    [rel_param, ..] -> {
      let rel_value =
        rel_param
        |> string.trim()
        |> string.drop_start(4)
        |> string.trim()
        |> string.drop_start(1)
        |> string.drop_end(1)

      Ok(
        rel_value
        |> string.split(" ")
        |> list.filter(fn(value) { string.trim(value) != "" })
        |> list.map(string.trim),
      )
    }
  }
}

fn assign_relations(
  url: String,
  relations: List(String),
  links: PageLinks,
) -> PageLinks {
  case relations {
    [] -> links
    [relation, ..rest] -> {
      let updated = case relation {
        "next" -> PageLinks(..links, next: Some(url))
        "differences" -> PageLinks(..links, differences: Some(url))
        "prev" -> PageLinks(..links, prev: Some(url))
        "first" -> PageLinks(..links, first: Some(url))
        "last" -> PageLinks(..links, last: Some(url))
        _ -> links
      }

      assign_relations(url, rest, updated)
    }
  }
}

fn merge_links(a: PageLinks, b: PageLinks) -> PageLinks {
  let PageLinks(
    next: next_a,
    differences: differences_a,
    prev: prev_a,
    first: first_a,
    last: last_a,
  ) = a
  let PageLinks(
    next: next_b,
    differences: differences_b,
    prev: prev_b,
    first: first_b,
    last: last_b,
  ) = b

  PageLinks(
    next: option.or(next_a, next_b),
    differences: option.or(differences_a, differences_b),
    prev: option.or(prev_a, prev_b),
    first: option.or(first_a, first_b),
    last: option.or(last_a, last_b),
  )
}
