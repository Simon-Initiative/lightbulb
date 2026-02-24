# Product Requirements Document: deep_linking

## 1. Problem / User Value
Lightbulb needs full Deep Linking 2.0 support so tools can accept deep-link launches and return standards-compliant content selections.

## 2. Scope
### In scope
- `LtiDeepLinkingRequest` claim/model support.
- Deep-link response JWT generation.
- Content-item builders and form-post helper.

### Out of scope
- Core audience/provider semantics beyond deep-link integration points.

## 3. Requirements in Scope
- FR-CORE-03 (deep-linking message type support)
- FR-DL-01
- FR-DL-02
- NFR-01
- NFR-02
- NFR-04

## 4. Success Criteria
- Typed deep-link request settings API available.
- Valid signed deep-link response JWTs and POST helper available.
- Conformance-style deep-link tests pass.
