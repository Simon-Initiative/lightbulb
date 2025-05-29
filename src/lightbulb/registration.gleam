/// Represents an LTI registration including information about the
/// platform such as the name, issuer, client ID, and service endpoints.
pub type Registration {
  Registration(
    name: String,
    issuer: String,
    client_id: String,
    auth_endpoint: String,
    access_token_endpoint: String,
    keyset_url: String,
  )
}
