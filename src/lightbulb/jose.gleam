import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}

pub type JoseJwk =
  Dict(String, String)

pub type Claims =
  Dict(String, Dynamic)

pub type JoseJwt {
  JoseJwt(claims: Claims)
}

pub type JoseJwsAlg

pub type JoseJws {
  JoseJws(alg: JoseJwsAlg, payload: String, headers: Claims)
}

@external(erlang, "jose_jwt", "sign")
/// Signs string claims with the provided JWK.
pub fn sign(
  jwk: Dict(String, String),
  token: Dict(String, String),
) -> #(JoseJws, Dict(String, String))

@external(erlang, "jose_jwt", "sign")
/// Signs dynamic claims with an explicit JWS header map.
pub fn sign_with_jws(
  jwk: Dict(String, String),
  jws: Dict(String, String),
  token: Dict(String, Dynamic),
) -> #(JoseJws, Dict(String, String))

@external(erlang, "jose_jws", "compact")
/// Serializes a signed JWS/JWT map into compact form.
pub fn compact(signed: Dict(String, String)) -> #(Dict(String, String), String)

@external(erlang, "jose_jwt", "verify")
/// Verifies a compact JWT with a JWK.
pub fn verify(jwk: JoseJwk, signed_token: String) -> #(Bool, JoseJwt, JoseJws)

@external(erlang, "jose_jwt", "peek")
/// Reads JWT claims without signature verification.
pub fn peek(jwt_string: String) -> JoseJwt

@external(erlang, "jose_jwt", "peek_protected")
/// Reads protected JWS headers without signature verification.
pub fn peek_protected(jwt_string: String) -> JoseJws

@external(erlang, "jose_jwt", "to_binary")
/// Serializes a JWT structure to a compact token string.
pub fn to_binary(jwt: JoseJwt) -> String

@external(erlang, "jose_jwt", "from_binary")
/// Parses a compact token string into a JWT structure.
pub fn from_binary(jwt_string: String) -> JoseJwt

/// JWK
@external(erlang, "jose_jwk", "from_map")
/// Builds a JOSE JWK from a raw map.
pub fn from_map(map: Dict(String, String)) -> JoseJwk

@external(erlang, "jose_jwk", "from_pem")
/// Builds a JOSE JWK from PEM content.
pub fn from_pem(pem: String) -> JoseJwk

@external(erlang, "jose_jwk", "to_public")
/// Returns the public portion of a JWK.
pub fn to_public(jwk: JoseJwk) -> JoseJwk

/// This function will take a JoseJwk and convert it to a PEM string.
/// Returns a tuple of the form #(params, pem) where params is a map of
/// parameters and pem is the PEM string. The params map should contain
/// the Kty (the key type).
@external(erlang, "jose_jwk", "to_pem")
/// Converts a JWK into JOSE params plus PEM string.
pub fn to_pem(jwk: JoseJwk) -> #(Dict(String, Dynamic), String)

@external(erlang, "jose_jwk", "to_map")
/// Converts a JWK into JOSE params and key map values.
pub fn to_map(jwk: JoseJwk) -> #(Dict(String, Dynamic), Dict(String, String))

pub type GenerateKeyParams {
  Rsa(modulus_size: Int)
}

@external(erlang, "jose_jwk", "generate_key")
/// Generates a keypair from the provided parameters.
pub fn generate_key(params: GenerateKeyParams) -> JoseJwk
