# Product Requirements Document

## 1. Feature Summary
- Name: Lightbulb Deep Linking JWT Profiles
- Last Updated: 2026-03-06
- Status: Draft

`lightbulb` currently builds Deep Linking response JWTs with a single claim-shaping strategy. Some LMS platforms (notably Canvas) require platform-specific identity claim semantics for interoperability, while others work with the default shape. This feature adds configurable platform-aware JWT shaping with safe defaults so tools can use standards-compliant behavior by default and enable targeted LMS overrides only when needed.

## 2. Goals and Non-Goals
### Goals
- Add first-class support in `lightbulb` for LMS-specific Deep Linking response JWT shaping.
- Keep existing default behavior unchanged for consumers that do not opt in.
- Provide a built-in Canvas profile.
- Provide an extension point for custom profile logic by tool developers.
- Preserve existing Deep Linking validation and signing behavior.

### Non-Goals
- Auto-detect every LMS with perfect certainty.
- Add UI/config management in this repository for profile selection.
- Change launch validation behavior outside Deep Linking response JWT shaping.
- Introduce breaking API changes for existing `build_response_jwt` users.

## 3. Users and Primary Use Cases
- Personas:
  - LTI tool library maintainers (`lightbulb` developers).
  - LTI tool implementers integrating multiple LMS platforms.
- User stories:
  - As a tool developer, I can keep default JWT generation for standards-compliant LMSs.
  - As a tool developer, I can enable a Canvas profile to satisfy Canvas claim expectations.
  - As a tool developer, I can plug in a custom JWT claim shaper for LMS-specific interop needs without forking `lightbulb`.

## 4. Functional Requirements
1. `lightbulb/deep_linking` must keep `build_response_jwt(...)` behavior backward-compatible and unchanged.
2. `lightbulb/deep_linking` must add a new API to build response JWTs with profile/override support.
3. The new API must support at least:
   - `Standard` profile (current default claim shape).
   - `Canvas` profile (Canvas-compatible identity claim shape).
   - `Custom` override hook (user-supplied claim transformer).
4. The API must preserve current validations:
   - return URL validation,
   - content item validation against deep-link settings,
   - signing with active JWK.
5. The API must expose deterministic precedence rules:
   - start from standard claims,
   - apply selected built-in profile transform,
   - apply optional custom transform.
6. Invalid override output (missing required claims or wrong types) must return a deep-linking error, not produce malformed JWTs.
7. Built-in Canvas profile must produce claims compatible with Canvas deep-link response expectations.
8. Documentation must include usage examples for Standard, Canvas, and Custom modes.

## 5. Non-Functional Requirements
- Reliability:
  - Profile transforms must fail safely with typed errors.
  - Existing behavior must remain stable for current users.
- Performance:
  - Additional shaping step must add negligible latency compared to signing.
- Security/Compliance:
  - No bypass of existing item and return URL validation.
  - Preserve cryptographic signing semantics and header behavior.
- Observability:
  - Expose optional metadata (or docs guidance) for logging selected profile and failure category at caller level.

## 6. Success Metrics
- Product metrics:
  - Canvas deep-link response succeeds without app-level custom JWT code.
  - Existing non-Canvas integrations continue working with default API.
- Technical metrics:
  - Unit + contract tests cover Standard, Canvas, and Custom profile paths.
  - Existing deep-linking tests remain green.

## 7. Dependencies and Constraints
- Internal dependencies:
  - `lightbulb/deep_linking.gleam`
  - `lightbulb/errors.gleam`
  - `lightbulb/deep_linking/content_item.gleam`
- External dependencies:
  - LTI 1.3 + Deep Linking 2.0 interoperability behavior across LMSs.
- Constraints:
  - Maintain source compatibility for current `build_response_jwt` callers.
  - Keep API ergonomics simple for Gleam users.

## 8. Risks and Mitigations
- Risk: Overfitting built-in profiles to one LMS version.
- Mitigation: Keep profile logic minimal and provide custom override hook.

- Risk: Profile transforms produce invalid claims.
- Mitigation: Validate final claim set before signing and return typed errors.

- Risk: Confusion about which path to use.
- Mitigation: Keep old API as default path and provide clear docs/migration notes.

## 9. Acceptance Criteria
1. Given an existing caller using `build_response_jwt`, when they upgrade `lightbulb`, then behavior remains unchanged.
2. Given a caller using `Canvas` profile, when generating deep-link response JWT, then JWT claims include Canvas-compatible identity semantics and Canvas accepts the response.
3. Given a caller using `Custom` profile override, when override returns valid claims, then JWT signs and posts successfully.
4. Given a caller override that removes required claims, when building JWT, then API returns a typed deep-linking error.
5. Given existing deep-linking tests, when feature is merged, then tests pass with added profile coverage.
