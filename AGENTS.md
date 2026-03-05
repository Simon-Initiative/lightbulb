# AGENTS

## Project Scope

- This file defines local agent guidance for the `lightbulb` repository.

## Project Overview

- `lightbulb` is a Gleam library for building LTI 1.3 tools.
- Core responsibilities include OIDC login, launch validation, and LTI service integrations.
- Current service coverage includes AGS (Assignments and Grades), NRPS (Names and Roles), and Deep Linking.
- Provider interfaces are designed to keep storage and HTTP concerns pluggable.

## Architecture

- Entry module:
  - `src/lightbulb.gleam` re-exports primary APIs for consumers.
- Launch/auth core:
  - `src/lightbulb/tool.gleam` handles OIDC login, JWT verification, claim validation, and message-type routing.
- Feature modules:
  - `src/lightbulb/services/access_token.gleam` builds OAuth client assertions and fetches service tokens.
  - `src/lightbulb/services/ags*.gleam` implements AGS line item and score workflows.
  - `src/lightbulb/services/nrps*.gleam` implements membership retrieval.
  - `src/lightbulb/deep_linking*.gleam` handles deep-link settings, content items, response JWT, and form-post helper.
- Provider boundary:
  - `src/lightbulb/providers/data_provider.gleam` defines persistence/key/registration interfaces.
  - `src/lightbulb/providers/http_provider.gleam` abstracts HTTP transport.
  - `src/lightbulb/providers/memory_provider.gleam` offers in-memory development/testing storage.
- Crypto/key utilities:
  - `src/lightbulb/jose.gleam` and `src/lightbulb/jwk.gleam` wrap JOSE/JWK operations.
- Tests:
  - `test/lightbulb/**` contains unit and integration-style tests grouped by domain.

## Engineering Workflow

- Keep changes minimal and scoped to the feature/bug request.
- Prefer additive changes over broad refactors unless refactoring is required for correctness.
- Run focused tests first, then broader tests when behavior changes cross module boundaries.
- Prefer explicit `Result` error paths over exceptions or panics.
- When working from a feature `plan.md`, check off checklist items when tasks are completed.
- For any public API or client-facing behavior change, update `CHANGELOG.md` in the same change:
  - add/update notes under `Unreleased` (WIP) until release day
  - note the intended target version
  - summarize what changed for consumers
  - include concrete migration steps/code changes required in client apps
  - when cutting a release, promote `Unreleased` notes into the released version section

## Gleam Conventions

- Prefer explicit, typed decoding and structured error types for public APIs.
- Reuse existing modules and patterns before introducing new helpers.
- For boolean early-return checks, prefer `gleam/bool.guard`.
- Prefer returning `Result(_, ErrorType)` with explicit error variants rather than raw strings.
- When string errors are needed for compatibility, provide dedicated conversion helpers
  (for example `lightbulb/errors.*_to_string`) instead of ad-hoc string literals.

Preferred pattern:

```gleam
use <- bool.guard(
  when: some_condition,
  return: Error("some.error.code"),
)
```

- Avoid creating custom `bool_guard` wrappers when `bool.guard` is sufficient.
