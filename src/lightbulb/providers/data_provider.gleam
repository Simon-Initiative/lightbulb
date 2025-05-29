import lightbulb/deployment.{type Deployment}
import lightbulb/jwk.{type Jwk}
import lightbulb/nonce.{type Nonce}
import lightbulb/registration.{type Registration}

/// Represents a data provider that can handle various operations related to
/// LTI (Learning Tools Interoperability) such as creating nonces,
/// validating nonces, retrieving registrations, deployments, and active JWKs.
pub type DataProvider {
  DataProvider(
    create_nonce: fn() -> Result(Nonce, String),
    validate_nonce: fn(String) -> Result(Nil, String),
    get_registration: fn(String, String) -> Result(Registration, String),
    get_deployment: fn(String, String, String) -> Result(Deployment, String),
    get_active_jwk: fn() -> Result(Jwk, String),
  )
}
