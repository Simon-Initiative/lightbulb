# Implementation Plan

## Phase 0 - Alignment and API Review
### Deliverables
- Finalized API shape for profile-aware deep-link JWT generation.

### Tasks
- [x] Confirm backward-compatibility guarantees for existing `build_response_jwt` callers.
- [x] Confirm new public API names/types (`ResponseJwtProfile`, `ClaimTransform`, `ResponseJwtContext`).
- [x] Confirm initial built-in profile set (`Standard`, `Canvas`).
- [x] Confirm final claim validation rules after transforms.

### Verification
- [ ] PRD and FDD approved by maintainers.
- [ ] Open API naming questions resolved.

## Phase 1 - Core API and Profile Plumbing
### Deliverables
- New profile-aware deep-link JWT API with standard fallback behavior.

### Tasks
- [x] Add new types for response JWT profiles and transform context in `deep_linking.gleam`.
- [x] Implement `build_response_jwt_with_profile(...)`.
- [x] Refactor existing claim construction into reusable helper(s) for base standard claims.
- [x] Keep `build_response_jwt(...)` behavior unchanged (or delegate to `Standard`).
- [x] Add final-claims validation helper enforcing required claim presence/type.

### Verification
- [ ] Existing deep-linking tests still pass unchanged.
- [ ] New API compiles and signs JWT with `Standard` profile.

## Phase 2 - Built-In Canvas Profile
### Deliverables
- Built-in Canvas claim shaping profile.

### Tasks
- [x] Implement Canvas transform logic (`iss/sub/azp = client_id`, `aud = platform_issuer`).
- [x] Add robust client-id extraction from request `aud` (string/list handling).
- [x] Validate Canvas transform output with final-claims validator.
- [x] Add profile-specific tests for claim outputs and error cases.

### Verification
- [ ] Unit tests assert expected Canvas claim semantics.
- [ ] JWT signing and claim integrity pass for Canvas profile.

## Phase 3 - Custom Override Hook and Error Hardening
### Deliverables
- User-supplied claim override support with typed errors.

### Tasks
- [x] Implement `Custom` profile transform callback execution.
- [x] Add new `DeepLinkingError` variants for invalid profile output.
- [x] Ensure custom transform failures are mapped to deterministic errors.
- [x] Add tests for valid custom transforms and broken custom transforms.

### Verification
- [ ] Contract tests verify custom profile path signs when claims remain valid.
- [ ] Invalid custom output returns typed deep-linking error.

## Phase 4 - Docs, Examples, and Manual QA
### Deliverables
- Developer documentation and interop validation notes.

### Tasks
- [x] Add docs section describing when to use `Standard` vs `Canvas` vs `Custom`.
- [x] Add copy-paste examples for profile selection by issuer.
- [x] Add migration notes for existing callers (optional adoption path).
- [ ] Execute manual QA against Canvas and at least one non-Canvas LMS.

### Verification
- [ ] Canvas deep-link flow succeeds with built-in profile.
- [ ] Non-Canvas flow succeeds with `Standard` profile.
- [ ] Final handoff notes include known limitations and future profile additions.

## PR Grouping (Recommended)
- PR Group 1: Phases 0-1 (API + core plumbing, no Canvas-specific behavior yet).
- PR Group 2: Phase 2 (Canvas profile + tests).
- PR Group 3: Phases 3-4 (custom override, docs, manual QA evidence).

## Task Authoring Notes
- Keep all tasks unchecked until implementation is completed.
- Prefer additive changes with no breaking changes to existing APIs.
- Prioritize high-signal tests for claim-shaping correctness before adding more LMS profiles.
