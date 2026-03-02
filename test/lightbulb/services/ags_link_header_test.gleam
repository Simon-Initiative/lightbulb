import gleam/option.{None, Some}
import gleeunit/should
import lightbulb/http/link_header

pub fn parse_link_header_test() {
  link_header.parse(
    "<https://example.com/items?page=2>; rel=\"next\", <https://example.com/items?page=1>; rel=\"first\", <https://example.com/items?page=4>; rel=\"last\", <https://example.com/items?page=1>; rel=\"prev\"",
  )
  |> should.equal(
    Ok(link_header.PageLinks(
      next: Some("https://example.com/items?page=2"),
      prev: Some("https://example.com/items?page=1"),
      first: Some("https://example.com/items?page=1"),
      last: Some("https://example.com/items?page=4"),
    )),
  )
}

pub fn malformed_link_header_test() {
  let result = link_header.parse("broken-link")

  case result {
    Error(link_header.InvalidLinkHeader(_)) -> True |> should.equal(True)
    _ -> False |> should.equal(True)
  }
}

pub fn empty_links_default_test() {
  link_header.empty_page_links()
  |> should.equal(link_header.PageLinks(
    next: None,
    prev: None,
    first: None,
    last: None,
  ))
}
