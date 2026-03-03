import gleam/dynamic/decode
import gleam/option.{type Option, None}

/// Represents a membership in the NRPS (Names and Roles Provisioning Service).
pub type Membership {
  Membership(
    user_id: String,
    roles: List(String),
    status: Option(String),
    name: Option(String),
    given_name: Option(String),
    family_name: Option(String),
    middle_name: Option(String),
    email: Option(String),
    picture: Option(String),
    lis_person_sourcedid: Option(String),
  )
}

/// Decodes an NRPS membership object.
pub fn decoder() {
  use user_id <- decode.field("user_id", decode.string)
  use roles <- decode.field("roles", decode.list(decode.string))
  use status <- decode.optional_field(
    "status",
    None,
    decode.optional(decode.string),
  )
  use name <- decode.optional_field(
    "name",
    None,
    decode.optional(decode.string),
  )
  use given_name <- decode.optional_field(
    "given_name",
    None,
    decode.optional(decode.string),
  )
  use family_name <- decode.optional_field(
    "family_name",
    None,
    decode.optional(decode.string),
  )
  use middle_name <- decode.optional_field(
    "middle_name",
    None,
    decode.optional(decode.string),
  )
  use email <- decode.optional_field(
    "email",
    None,
    decode.optional(decode.string),
  )
  use picture <- decode.optional_field(
    "picture",
    None,
    decode.optional(decode.string),
  )
  use lis_person_sourcedid <- decode.optional_field(
    "lis_person_sourcedid",
    None,
    decode.optional(decode.string),
  )

  decode.success(Membership(
    user_id: user_id,
    roles: roles,
    status: status,
    name: name,
    given_name: given_name,
    family_name: family_name,
    middle_name: middle_name,
    email: email,
    picture: picture,
    lis_person_sourcedid: lis_person_sourcedid,
  ))
}
