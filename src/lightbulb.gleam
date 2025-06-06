import lightbulb/providers/data_provider
import lightbulb/tool

// Export tool module types and functions for convinience

/// A DataProvider is a record type that implements the required functions to
/// provide data to the tool. See the `lightbulb/providers/data_provider` module for
/// more details. 
pub type DataProvider =
  data_provider.DataProvider

/// Builds an OIDC login response for the tool. This function will return a `state` and `redirect_url`.
/// The `state` is an opaque string that will be used to verify the response from the
/// OIDC provider. The `redirect_url` is the URL that the user will be redirected to
/// to authenticate and complete the OIDC login process.
pub const oidc_login = tool.oidc_login

/// Validates the OIDC login response from the OIDC provider. This function will validate and unpack
/// the `id_token` and return claims as a map if the token is valid. The `state` parametrer is the
/// opaque string that was stored in a cookie during `oidc_login` step.
pub const validate_launch = tool.validate_launch
