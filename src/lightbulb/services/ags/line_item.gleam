import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option, None}

/// Represents a line item in the AGS (Assignment Grading Service).
pub type LineItem {
  LineItem(
    id: Option(String),
    score_maximum: Float,
    label: String,
    resource_id: String,
    resource_link_id: Option(String),
    tag: Option(String),
    start_date_time: Option(String),
    end_date_time: Option(String),
    grades_released: Option(Bool),
  )
}

/// Converts a `LineItem` to a JSON representation.
pub fn to_json(line_item: LineItem) -> Json {
  let LineItem(
    id,
    score_maximum,
    label,
    resource_id,
    resource_link_id,
    tag,
    start_date_time,
    end_date_time,
    grades_released,
  ) = line_item

  [
    #("scoreMaximum", json.float(score_maximum)),
    #("label", json.string(label)),
    #("resourceId", json.string(resource_id)),
  ]
  |> maybe_add(id, "id", json.string)
  |> maybe_add(resource_link_id, "resourceLinkId", json.string)
  |> maybe_add(tag, "tag", json.string)
  |> maybe_add(start_date_time, "startDateTime", json.string)
  |> maybe_add(end_date_time, "endDateTime", json.string)
  |> maybe_add(grades_released, "gradesReleased", json.bool)
  |> json.object()
}

fn maybe_add(
  list: List(#(String, Json)),
  field: Option(a),
  key: String,
  json_encoder: fn(a) -> Json,
) {
  field
  |> option.map(fn(value) { [#(key, json_encoder(value)), ..list] })
  |> option.unwrap(list)
}

/// Decodes a JSON object into a `LineItem`.
pub fn decoder() {
  use id <- decode.optional_field("id", None, decode.optional(decode.string))
  use score_maximum <- decode.field("scoreMaximum", decode.float)
  use label <- decode.field("label", decode.string)
  use resource_id <- decode.field("resourceId", decode.string)
  use resource_link_id <- decode.optional_field(
    "resourceLinkId",
    None,
    decode.optional(decode.string),
  )
  use tag <- decode.optional_field("tag", None, decode.optional(decode.string))
  use start_date_time <- decode.optional_field(
    "startDateTime",
    None,
    decode.optional(decode.string),
  )
  use end_date_time <- decode.optional_field(
    "endDateTime",
    None,
    decode.optional(decode.string),
  )
  use grades_released <- decode.optional_field(
    "gradesReleased",
    None,
    decode.optional(decode.bool),
  )

  decode.success(LineItem(
    id: id,
    score_maximum: score_maximum,
    label: label,
    resource_id: resource_id,
    resource_link_id: resource_link_id,
    tag: tag,
    start_date_time: start_date_time,
    end_date_time: end_date_time,
    grades_released: grades_released,
  ))
}
