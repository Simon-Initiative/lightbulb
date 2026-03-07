pub type NonceError {
  NonceInvalid
  NonceExpired
  NonceReplayed
}

/// Converts nonce-validation errors to human-readable messages.
pub fn nonce_error_to_string(error: NonceError) -> String {
  case error {
    NonceInvalid -> "Invalid nonce."
    NonceExpired -> "Nonce has expired."
    NonceReplayed -> "Nonce has already been used."
  }
}

pub type CoreError {
  LoginMissingParam(param: String)
  LaunchMissingParam(param: String)
  JwtInvalidSignature
  JwtInvalidClaim
  JwtExpired
  JwtNotYetValid
  AudienceInvalid
  RegistrationNotFound
  DeploymentNotFound
  StateInvalid
  StateNotFound
  TargetLinkUriMismatch
  NonceValidationError(error: NonceError)
  MessageTypeUnsupported
}

/// Converts core launch-validation errors to human-readable messages.
pub fn core_error_to_string(error: CoreError) -> String {
  case error {
    LoginMissingParam(param) ->
      "Missing required login parameter: " <> param <> "."
    LaunchMissingParam(param) ->
      "Missing required launch parameter: " <> param <> "."
    JwtInvalidSignature -> "Invalid token signature."
    JwtInvalidClaim -> "Token claims are invalid."
    JwtExpired -> "Token has expired."
    JwtNotYetValid -> "Token is not yet valid."
    AudienceInvalid -> "Token audience is invalid."
    RegistrationNotFound -> "No matching registration was found."
    DeploymentNotFound -> "No matching deployment was found."
    StateInvalid -> "Invalid state."
    StateNotFound -> "State context was not found or has expired."
    TargetLinkUriMismatch -> "Target link URI does not match login context."
    NonceValidationError(nonce_error) -> nonce_error_to_string(nonce_error)
    MessageTypeUnsupported -> "Unsupported LTI message type."
  }
}

pub type DeepLinkingError {
  DeepLinkingClaimMissing
  DeepLinkingClaimInvalid
  DeepLinkingProfileInvalid
  DeepLinkingProfileClaimMissing(claim: String)
  DeepLinkingProfileClaimInvalid(claim: String)
  DeepLinkingSettingsInvalid
  DeepLinkingResponseInvalidItemType
  DeepLinkingResponseMultipleNotAllowed
  DeepLinkingResponseInvalidReturnUrl
  DeepLinkingResponseSigningFailed
}

/// Converts deep-linking errors to human-readable messages.
pub fn deep_linking_error_to_string(error: DeepLinkingError) -> String {
  case error {
    DeepLinkingClaimMissing -> "Missing required deep-linking claim."
    DeepLinkingClaimInvalid -> "Deep-linking claim has invalid format."
    DeepLinkingProfileInvalid -> "Deep-linking profile transform failed."
    DeepLinkingProfileClaimMissing(claim) ->
      "Deep-linking profile output is missing required claim: " <> claim <> "."
    DeepLinkingProfileClaimInvalid(claim) ->
      "Deep-linking profile output has invalid claim type: " <> claim <> "."
    DeepLinkingSettingsInvalid -> "Deep-linking settings are invalid."
    DeepLinkingResponseInvalidItemType ->
      "Response contains an unsupported item type."
    DeepLinkingResponseMultipleNotAllowed ->
      "Multiple items are not allowed for this deep-linking request."
    DeepLinkingResponseInvalidReturnUrl -> "Deep-link return URL is invalid."
    DeepLinkingResponseSigningFailed -> "Failed to sign deep-linking response."
  }
}
