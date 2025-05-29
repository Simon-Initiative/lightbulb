import gleam/dynamic/decode

/// Represents a membership in the NRPS (Names and Roles Provisioning Service).
pub type Membership {
  Membership(
    user_id: String,
    status: String,
    name: String,
    given_name: String,
    family_name: String,
    email: String,
    roles: List(String),
    picture: String,
  )
}

/// Converts a `Membership` to a JSON representation.
pub fn decoder() {
  use user_id <- decode.field("user_id", decode.string)
  use status <- decode.field("status", decode.string)
  use name <- decode.field("name", decode.string)
  use given_name <- decode.field("given_name", decode.string)
  use family_name <- decode.field("family_name", decode.string)
  use email <- decode.field("email", decode.string)
  use roles <- decode.field("roles", decode.list(decode.string))
  use picture <- decode.field("picture", decode.string)

  decode.success(Membership(
    user_id: user_id,
    status: status,
    name: name,
    given_name: given_name,
    family_name: family_name,
    email: email,
    roles: roles,
    picture: picture,
  ))
}
