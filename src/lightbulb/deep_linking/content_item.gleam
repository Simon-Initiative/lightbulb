import gleam/bool
import gleam/dict
import gleam/dynamic
import gleam/list
import gleam/option.{type Option}
import lightbulb/deep_linking/settings.{type DeepLinkingSettings}
import lightbulb/errors.{
  type DeepLinkingError,
  DeepLinkingResponseInvalidItemType,
  DeepLinkingResponseMultipleNotAllowed,
}

pub type LineItem {
  LineItem(
    score_maximum: Float,
    resource_id: Option(String),
    tag: Option(String),
    label: Option(String),
    grades_released: Option(Bool),
  )
}

/// Content items supported for deep-linking responses.
pub type ContentItem {
  Link(url: String, title: Option(String), text: Option(String))
  LtiResourceLink(
    url: Option(String),
    title: Option(String),
    text: Option(String),
    custom: Option(dict.Dict(String, String)),
    line_item: Option(LineItem),
  )
  File(url: String, title: Option(String), media_type: Option(String))
  Html(html: String)
  Image(url: String, title: Option(String), alt: Option(String))
}

/// Creates a `link` content item.
pub fn link(
  url: String,
  title: Option(String),
  text: Option(String),
) -> ContentItem {
  Link(url: url, title: title, text: text)
}

/// Creates an `ltiResourceLink` content item.
pub fn lti_resource_link(
  url: Option(String),
  title: Option(String),
  text: Option(String),
  custom: Option(dict.Dict(String, String)),
  line_item: Option(LineItem),
) -> ContentItem {
  LtiResourceLink(
    url: url,
    title: title,
    text: text,
    custom: custom,
    line_item: line_item,
  )
}

/// Returns the Deep Linking item type string for a content item.
pub fn item_type(item: ContentItem) -> String {
  case item {
    Link(..) -> "link"
    LtiResourceLink(..) -> "ltiResourceLink"
    File(..) -> "file"
    Html(..) -> "html"
    Image(..) -> "image"
  }
}

/// Validates content items against deep-linking settings constraints.
///
/// Enforced rules:
/// - item type must be listed in `accept_types`
/// - if `accept_multiple` is false, only one item may be returned
/// - if `accept_lineitem` is false, lineItem payloads are rejected
pub fn validate_items(
  settings: DeepLinkingSettings,
  items: List(ContentItem),
) -> Result(Nil, DeepLinkingError) {
  use <- bool.guard(
    when: !all_item_types_allowed(items, settings.accept_types),
    return: Error(DeepLinkingResponseInvalidItemType),
  )

  use <- bool.guard(
    when: option.unwrap(settings.accept_multiple, False) == False
      && list.length(items) > 1,
    return: Error(DeepLinkingResponseMultipleNotAllowed),
  )

  use <- bool.guard(
    when: option.unwrap(settings.accept_lineitem, False) == False
      && list.any(items, fn(item) { item_has_line_item(item) }),
    return: Error(DeepLinkingResponseInvalidItemType),
  )

  Ok(Nil)
}

fn all_item_types_allowed(
  items: List(ContentItem),
  accept_types: List(String),
) -> Bool {
  list.all(items, fn(item) { list.contains(accept_types, item_type(item)) })
}

fn item_has_line_item(item: ContentItem) -> Bool {
  case item {
    LtiResourceLink(line_item: option.Some(_), ..) -> True
    _ -> False
  }
}

/// Encodes a content item to dynamic data for JWT claim construction.
pub fn to_dynamic(item: ContentItem) -> dynamic.Dynamic {
  case item {
    Link(url, title, text) ->
      [
        #("type", dynamic.string("link")),
        #("url", dynamic.string(url)),
      ]
      |> maybe_add_optional(title, "title", dynamic.string)
      |> maybe_add_optional(text, "text", dynamic.string)
      |> object()

    LtiResourceLink(url, title, text, custom, line_item) ->
      [
        #("type", dynamic.string("ltiResourceLink")),
      ]
      |> maybe_add_optional(url, "url", dynamic.string)
      |> maybe_add_optional(title, "title", dynamic.string)
      |> maybe_add_optional(text, "text", dynamic.string)
      |> maybe_add_optional(custom, "custom", custom_to_dynamic)
      |> maybe_add_optional(line_item, "lineItem", line_item_to_dynamic)
      |> object()

    File(url, title, media_type) ->
      [
        #("type", dynamic.string("file")),
        #("url", dynamic.string(url)),
      ]
      |> maybe_add_optional(title, "title", dynamic.string)
      |> maybe_add_optional(media_type, "mediaType", dynamic.string)
      |> object()

    Html(html) ->
      [#("type", dynamic.string("html")), #("html", dynamic.string(html))]
      |> object()

    Image(url, title, alt) ->
      [
        #("type", dynamic.string("image")),
        #("url", dynamic.string(url)),
      ]
      |> maybe_add_optional(title, "title", dynamic.string)
      |> maybe_add_optional(alt, "alt", dynamic.string)
      |> object()
  }
}

fn line_item_to_dynamic(item: LineItem) -> dynamic.Dynamic {
  let LineItem(score_maximum, resource_id, tag, label, grades_released) = item

  [
    #("scoreMaximum", dynamic.float(score_maximum)),
  ]
  |> maybe_add_optional(resource_id, "resourceId", dynamic.string)
  |> maybe_add_optional(tag, "tag", dynamic.string)
  |> maybe_add_optional(label, "label", dynamic.string)
  |> maybe_add_optional(grades_released, "gradesReleased", dynamic.bool)
  |> object()
}

fn custom_to_dynamic(custom: dict.Dict(String, String)) -> dynamic.Dynamic {
  custom
  |> dict.to_list()
  |> list.map(fn(pair) { #(dynamic.string(pair.0), dynamic.string(pair.1)) })
  |> dynamic.properties()
}

fn object(entries: List(#(String, dynamic.Dynamic))) -> dynamic.Dynamic {
  entries
  |> list.map(fn(entry) { #(dynamic.string(entry.0), entry.1) })
  |> dynamic.properties()
}

fn maybe_add_optional(
  entries: List(#(String, dynamic.Dynamic)),
  value: Option(a),
  key: String,
  encoder: fn(a) -> dynamic.Dynamic,
) {
  value
  |> option.map(fn(actual) { [#(key, encoder(actual)), ..entries] })
  |> option.unwrap(entries)
}
