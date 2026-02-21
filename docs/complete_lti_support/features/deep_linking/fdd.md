# Functional Design Document: deep_linking

## 1. Functional Scope
- Parse deep-linking settings from launch claims.
- Build typed content items for response.
- Sign and emit deep-link response JWT.
- Provide form-post helper to platform return URL.

## 2. Functional Architecture
### Public API
- New deep-linking module with request decoders and response builders.
- Typed content-item constructors (`ltiResourceLink`, `link`, lineItem extension).

### Internal Design
- Reuse existing JOSE signing path for response JWT generation.
- Validate required deep-link settings before response generation.

### Compatibility
- Additive APIs; no breaking changes to resource-link launch flows.

## 3. Runtime Flow
1. Validate deep-link launch message and settings claim.
2. Construct content items.
3. Build deep-link response claims (`data` echo when present).
4. Sign JWT and generate form-post payload.

## 4. Error Semantics
- Missing required deep-link settings fields -> explicit errors.
- Response generation with invalid inputs -> explicit builder errors.

## 5. Testability Design
- Unit tests for settings decode and content item encoding.
- Integration tests for response JWT claim set and form-post shape.
- Negative tests for malformed claims/signing failures.
