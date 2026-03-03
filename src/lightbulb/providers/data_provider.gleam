import gleam/time/timestamp.{type Timestamp}
import lightbulb/deployment.{type Deployment}
import lightbulb/errors.{type NonceError}
import lightbulb/jwk.{type Jwk}
import lightbulb/nonce.{type Nonce}
import lightbulb/registration.{type Registration}

pub type LoginContext {
  LoginContext(
    state: String,
    target_link_uri: String,
    issuer: String,
    client_id: String,
    expires_at: Timestamp,
  )
}

pub type LaunchContextError {
  LaunchContextInvalid
  LaunchContextNotFound
}

pub fn launch_context_error_to_string(error: LaunchContextError) -> String {
  case error {
    LaunchContextInvalid -> "Launch context is invalid."
    LaunchContextNotFound -> "Launch context was not found."
  }
}

pub type ProviderError {
  ProviderCreateNonceFailed
  ProviderRegistrationNotFound
  ProviderDeploymentNotFound
  ProviderActiveJwkNotFound
}

pub fn provider_error_to_string(error: ProviderError) -> String {
  case error {
    ProviderCreateNonceFailed -> "Failed to create nonce."
    ProviderRegistrationNotFound -> "Registration not found."
    ProviderDeploymentNotFound -> "Deployment not found."
    ProviderActiveJwkNotFound -> "Active JWK not found."
  }
}

/// Optional adapter surface for state/login-context storage semantics.
pub type LaunchContextProvider {
  LaunchContextProvider(
    save_login_context: fn(LoginContext) -> Result(Nil, LaunchContextError),
    get_login_context: fn(String) -> Result(LoginContext, LaunchContextError),
    consume_login_context: fn(String) -> Result(Nil, LaunchContextError),
  )
}

/// Represents a data provider that can handle various operations related to
/// LTI (Learning Tools Interoperability) such as creating nonces,
/// validating nonces, retrieving registrations, deployments, and active JWKs.
pub type DataProvider {
  DataProvider(
    create_nonce: fn() -> Result(Nonce, ProviderError),
    validate_nonce: fn(String) -> Result(Nil, NonceError),
    save_login_context: fn(LoginContext) -> Result(Nil, LaunchContextError),
    get_login_context: fn(String) -> Result(LoginContext, LaunchContextError),
    consume_login_context: fn(String) -> Result(Nil, LaunchContextError),
    get_registration: fn(String, String) -> Result(Registration, ProviderError),
    get_deployment: fn(String, String, String) ->
      Result(Deployment, ProviderError),
    get_active_jwk: fn() -> Result(Jwk, ProviderError),
  )
}

/// Adapter constructor that composes launch-context handlers with the remaining
/// data-provider operations.
pub fn from_parts(
  create_nonce: fn() -> Result(Nonce, ProviderError),
  validate_nonce: fn(String) -> Result(Nil, NonceError),
  launch_context: LaunchContextProvider,
  get_registration: fn(String, String) -> Result(Registration, ProviderError),
  get_deployment: fn(String, String, String) ->
    Result(Deployment, ProviderError),
  get_active_jwk: fn() -> Result(Jwk, ProviderError),
) -> DataProvider {
  let LaunchContextProvider(
    save_login_context: save_login_context,
    get_login_context: get_login_context,
    consume_login_context: consume_login_context,
  ) = launch_context

  DataProvider(
    create_nonce: create_nonce,
    validate_nonce: validate_nonce,
    save_login_context: save_login_context,
    get_login_context: get_login_context,
    consume_login_context: consume_login_context,
    get_registration: get_registration,
    get_deployment: get_deployment,
    get_active_jwk: get_active_jwk,
  )
}
