import birl.{type Time}

/// Represents a nonce used for security purposes, such as preventing replay attacks.
pub type Nonce {
  Nonce(nonce: String, expires_at: Time)
}
