# Functional Design Document: deep_linking

## 1. Normative References
- LTI Deep Linking 2.0: https://www.imsglobal.org/spec/lti-dl/v2p0/
- LTI Core 1.3 (launch and shared claims): https://www.imsglobal.org/spec/lti/v1p3
- LTI 1.3 certification guide (Deep Linking tool tests): https://www.imsglobal.org/spec/lti/v1p3/cert

Key normative points used in this design:
- Deep linking request message type is `LtiDeepLinkingRequest`.
- `deep_linking_settings` claim is required and includes required fields:
  - `deep_link_return_url`
  - `accept_types`
  - `accept_presentation_document_targets`
- Tool returns a Deep Linking response as a signed JWT, submitted via auto-post HTML form to `deep_link_return_url` using parameter name `JWT`.
- Deep linking response claim requirements include:
  - `aud` = request `iss`
  - `https://purl.imsglobal.org/spec/lti/claim/message_type = LtiDeepLinkingResponse`
  - `https://purl.imsglobal.org/spec/lti/claim/version = 1.3.0`
  - `https://purl.imsglobal.org/spec/lti/claim/deployment_id`
  - `https://purl.imsglobal.org/spec/lti-dl/claim/data` required only if request carried settings `data`
- `content_items` may be omitted or empty to indicate no item created.

## 2. Current Baseline and Gaps
Current codebase has no deep-linking-specific modules or API surface.

Gaps:
- No message validator path for `LtiDeepLinkingRequest` in `src/lightbulb/tool.gleam`.
- No decoder for `deep_linking_settings` claim.
- No deep linking response JWT builder.
- No content item models/builders.
- No form-post helper for `JWT` return to platform.
- No deep linking tests.

## 3. Target Public API

### 3.1 Modules
- `src/lightbulb/deep_linking.gleam`
- `src/lightbulb/deep_linking/settings.gleam`
- `src/lightbulb/deep_linking/content_item.gleam`

### 3.2 Types
- `DeepLinkingSettings`
  - required:
    - `deep_link_return_url: String`
    - `accept_types: List(String)`
    - `accept_presentation_document_targets: List(String)`
  - optional:
    - `accept_media_types: Option(String)`
    - `accept_multiple: Option(Bool)`
    - `auto_create: Option(Bool)`
    - `title: Option(String)`
    - `text: Option(String)`
    - `data: Option(String)`
    - `accept_lineitem: Option(Bool)`
- `DeepLinkingRequest`
  - shared launch claims + typed `deep_linking_settings`
- `DeepLinkingResponse`
  - required response claims and optional message/log/error fields
- `ContentItem` union
  - `Link`
  - `LtiResourceLink`
  - initially optional support for `File`, `Html`, `Image` can be staged, but include model hooks now

### 3.3 Builder APIs (additive)
- `get_deep_linking_settings(claims) -> Result(DeepLinkingSettings, String)`
- `build_response_jwt(request_claims, settings, items, options, active_jwk) -> Result(String, String)`
- `build_response_form_post(deep_link_return_url, jwt) -> String`
- content item constructors:
  - `content_item.link(...)`
  - `content_item.lti_resource_link(...)`
  - optional staged constructors for file/html/image

## 4. Content Item and Validation Rules

### 4.1 Type Acceptance
- Validate requested content item types against `settings.accept_types`.
- If `accept_multiple` is false, enforce max one returned item.
- If no items selected, allow empty response (`content_items` omitted or `[]`).

### 4.2 LTI Resource Link Item
For `ltiResourceLink` type:
- include `type = "ltiResourceLink"`
- include `url` when explicit launch URL should be returned
- support optional `custom` map (string values only)
- support optional `lineItem` object

### 4.3 Line Item in Deep Linking Item
- Include `lineItem` only when:
  - platform supports it (`accept_lineitem == true`) or tool chooses permissive fallback
- `lineItem.scoreMaximum` required when lineItem included.
- Include optional `resourceId`, `tag`, `label`, `gradesReleased` as available.

## 5. Response JWT Claims and Semantics
Required response claims:
- `aud`: request `iss`
- `https://purl.imsglobal.org/spec/lti/claim/message_type`: `LtiDeepLinkingResponse`
- `https://purl.imsglobal.org/spec/lti/claim/version`: `1.3.0`
- `https://purl.imsglobal.org/spec/lti/claim/deployment_id`: from request

Conditional claims:
- `https://purl.imsglobal.org/spec/lti-dl/claim/data`: must echo request settings `data` when present

Optional claims:
- `https://purl.imsglobal.org/spec/lti-dl/claim/content_items`
- `https://purl.imsglobal.org/spec/lti-dl/claim/msg`
- `https://purl.imsglobal.org/spec/lti-dl/claim/log`
- `https://purl.imsglobal.org/spec/lti-dl/claim/errormsg`
- `https://purl.imsglobal.org/spec/lti-dl/claim/errorlog`

JWT signing behavior:
- Sign with RS256 and active tool JWK.
- Include `kid` in JWS header.
- Include standard token time claims (`iat`, `exp`) with short TTL.

## 6. Core Integration Boundary
- `src/lightbulb/tool.gleam` message validation must recognize `LtiDeepLinkingRequest` and validate deep-linking-specific required claims.
- Core `validate_launch` should return claims that allow deep-linking feature to decode settings.
- Deep linking request handling should remain additive and not break resource-link launch flows.

## 7. Error Taxonomy
Preserve `Result(_, String)` externally, with deterministic categories:
- `deep_linking.claim.missing`
- `deep_linking.claim.invalid`
- `deep_linking.settings.invalid`
- `deep_linking.response.invalid_item_type`
- `deep_linking.response.multiple_not_allowed`
- `deep_linking.response.data_mismatch`
- `deep_linking.response.signing_failed`
- `deep_linking.response.invalid_return_url`

## 8. Runtime Flows

### 8.1 Request Handling
1. Receive validated launch claims from core path.
2. Verify message type is deep linking request.
3. Decode and validate `deep_linking_settings`.
4. Build UI context using settings constraints.

### 8.2 Response Handling
1. Build content item list from user selection.
2. Validate item types against `accept_types` and multiplicity constraints.
3. Build response claims (including conditional `data`).
4. Sign JWT.
5. Return auto-submit form HTML posting `JWT` to `deep_link_return_url`.

## 9. Testability Design

### 9.1 Unit Tests
- settings decode required/optional fields
- response claim builder required/conditional claims
- content item validation (type acceptance, accept_multiple)
- form-post helper output contract

### 9.2 Integration-Style Tests
- deep link launch claims -> settings decode -> response JWT -> form HTML flow
- JWT verification using active public key and claim assertions

### 9.3 Certification-Oriented Tests
- response format is deep linking response
- response timestamps valid
- RS256 + valid signature + matching `kid`
- required claims present with correct values
- proof-oriented flow support (response absorption path in example app)

## 10. File-Level Design Impact
- `src/lightbulb/tool.gleam`
- `src/lightbulb/deep_linking.gleam` (new)
- `src/lightbulb/deep_linking/settings.gleam` (new)
- `src/lightbulb/deep_linking/content_item.gleam` (new)
- `src/lightbulb/services/ags/line_item.gleam` (for shared lineItem shape reuse, optional)
- `test/lightbulb/deep_linking_test.gleam` (new)
- `test/lightbulb/core_test.gleam` (message-type route coverage)

## 11. Certification Traceability (Deep Linking)
Implementation and tests should explicitly map to Deep Linking tool-test objectives in the certification guide section 6.2, including:
- request receipt and response submission
- response format validity
- timestamp validity
- signature validity
- required claims verification
- response value affirmation behavior
