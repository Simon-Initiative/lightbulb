import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/option.{type Option, None}
import gleam/result

pub const claim_deep_linking_settings = "https://purl.imsglobal.org/spec/lti-dl/claim/deep_linking_settings"

pub type DeepLinkingSettings {
  DeepLinkingSettings(
    deep_link_return_url: String,
    accept_types: List(String),
    accept_presentation_document_targets: List(String),
    accept_media_types: Option(String),
    accept_multiple: Option(Bool),
    auto_create: Option(Bool),
    title: Option(String),
    text: Option(String),
    data: Option(String),
    accept_lineitem: Option(Bool),
  )
}

/// Decoder for the `deep_linking_settings` claim payload.
pub fn decoder() {
  use deep_link_return_url <- decode.field(
    "deep_link_return_url",
    decode.string,
  )
  use accept_types <- decode.field("accept_types", decode.list(decode.string))
  use accept_presentation_document_targets <- decode.field(
    "accept_presentation_document_targets",
    decode.list(decode.string),
  )
  use accept_media_types <- decode.optional_field(
    "accept_media_types",
    None,
    decode.optional(decode.string),
  )
  use accept_multiple <- decode.optional_field(
    "accept_multiple",
    None,
    decode.optional(decode.bool),
  )
  use auto_create <- decode.optional_field(
    "auto_create",
    None,
    decode.optional(decode.bool),
  )
  use title <- decode.optional_field(
    "title",
    None,
    decode.optional(decode.string),
  )
  use text <- decode.optional_field(
    "text",
    None,
    decode.optional(decode.string),
  )
  use data <- decode.optional_field(
    "data",
    None,
    decode.optional(decode.string),
  )
  use accept_lineitem <- decode.optional_field(
    "accept_lineitem",
    None,
    decode.optional(decode.bool),
  )

  decode.success(DeepLinkingSettings(
    deep_link_return_url: deep_link_return_url,
    accept_types: accept_types,
    accept_presentation_document_targets: accept_presentation_document_targets,
    accept_media_types: accept_media_types,
    accept_multiple: accept_multiple,
    auto_create: auto_create,
    title: title,
    text: text,
    data: data,
    accept_lineitem: accept_lineitem,
  ))
}

/// Extracts and decodes deep-linking settings from launch claims.
///
/// Returns:
/// - `Error("deep_linking.claim.missing")` when settings claim is absent
/// - `Error("deep_linking.settings.invalid")` when claim fails decode/validation
pub fn from_claims(claims: dict.Dict(String, Dynamic)) {
  dict.get(claims, claim_deep_linking_settings)
  |> result.map_error(fn(_) { "deep_linking.claim.missing" })
  |> result.try(fn(raw) {
    decode.run(raw, decoder())
    |> result.map_error(fn(_) { "deep_linking.settings.invalid" })
  })
}
