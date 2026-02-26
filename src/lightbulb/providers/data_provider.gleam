import lightbulb/deployment.{type Deployment}
import lightbulb/errors.{type NonceError}
import lightbulb/jwk.{type Jwk}
import lightbulb/nonce.{type Nonce}
import lightbulb/registration.{type Registration}
import birl.{type Time}

pub type LoginContext {
  LoginContext(
    state: String,
    target_link_uri: String,
    issuer: String,
    client_id: String,
    expires_at: Time,
  )
}

/// Represents a data provider that can handle various operations related to
/// LTI (Learning Tools Interoperability) such as creating nonces,
/// validating nonces, retrieving registrations, deployments, and active JWKs.
pub type DataProvider {
  DataProvider(
    create_nonce: fn() -> Result(Nonce, String),
    validate_nonce: fn(String) -> Result(Nil, NonceError),
    save_login_context: fn(LoginContext) -> Result(Nil, String),
    get_login_context: fn(String) -> Result(LoginContext, String),
    consume_login_context: fn(String) -> Result(Nil, String),
    get_registration: fn(String, String) -> Result(Registration, String),
    get_deployment: fn(String, String, String) -> Result(Deployment, String),
    get_active_jwk: fn() -> Result(Jwk, String),
  )
}
