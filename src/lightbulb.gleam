import lightbulb/deep_linking
import lightbulb/providers/data_provider
import lightbulb/tool

/// A DataProvider is a record type that implements the required functions to
/// provide data to the tool. See the `lightbulb/providers/data_provider` module for
/// more details.
pub type DataProvider =
  data_provider.DataProvider

/// Builds an OIDC login response for the tool. This function will return a `state` and `redirect_url`.
/// The `state` is an opaque string that will be used to verify the response from the
/// OIDC provider. The `redirect_url` is the URL that the user will be redirected to
/// to authenticate and complete the OIDC login process.
pub fn oidc_login(provider, params) {
  tool.oidc_login(provider, params)
}

/// Validates the OIDC login response from the OIDC provider. This function will validate and unpack
/// the `id_token` and return claims as a map if the token is valid. The `state` parametrer is the
/// opaque string that was stored in a cookie during `oidc_login` step.
pub fn validate_launch(provider, params, session_state) {
  tool.validate_launch(provider, params, session_state)
}

/// Decodes and validates the deep-linking settings claim from launch claims.
pub fn get_deep_linking_settings(claims) {
  deep_linking.get_deep_linking_settings(claims)
}

/// Builds a signed deep-linking response JWT payload.
pub fn build_deep_linking_response_jwt(
  request_claims,
  settings,
  items,
  options,
  active_jwk,
) {
  deep_linking.build_response_jwt(
    request_claims,
    settings,
    items,
    options,
    active_jwk,
  )
}

/// Builds an auto-submit HTML form that POSTs the deep-linking response JWT.
pub fn build_deep_linking_response_form_post(deep_link_return_url, jwt) {
  deep_linking.build_response_form_post(deep_link_return_url, jwt)
}
