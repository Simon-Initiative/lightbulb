import gleam/dynamic/decode
import gleam/option.{type Option, None}

/// Represents an AGS result item.
pub type Result {
  Result(
    id: Option(String),
    user_id: String,
    result_score: Option(Float),
    result_maximum: Option(Float),
    comment: Option(String),
    score_of: Option(String),
  )
}

pub fn decoder() {
  use id <- decode.optional_field("id", None, decode.optional(decode.string))
  use user_id <- decode.field("userId", decode.string)
  use result_score <- decode.optional_field(
    "resultScore",
    None,
    decode.optional(decode.float),
  )
  use result_maximum <- decode.optional_field(
    "resultMaximum",
    None,
    decode.optional(decode.float),
  )
  use comment <- decode.optional_field(
    "comment",
    None,
    decode.optional(decode.string),
  )
  use score_of <- decode.optional_field(
    "scoreOf",
    None,
    decode.optional(decode.string),
  )

  decode.success(Result(
    id: id,
    user_id: user_id,
    result_score: result_score,
    result_maximum: result_maximum,
    comment: comment,
    score_of: score_of,
  ))
}
