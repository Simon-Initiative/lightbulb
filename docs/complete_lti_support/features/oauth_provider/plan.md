# Implementation Plan: oauth_provider

## Phase 1: Token Tolerance and Error Mapping
- [ ] Make token decode tolerant for optional fields.
- [ ] Add structured OAuth error payload decoding.
- [ ] Add tests for success/error variants.

## Phase 2: Provider Contract Evolution
- [ ] Finalize provider extension vs separate provider abstraction.
- [ ] Implement updated semantics in memory provider and adapters.
- [ ] Add migration docs for external provider implementers.

## Phase 3: Optional Token Cache
- [ ] Decide cache inclusion scope.
- [ ] Implement cache utility keyed by issuer/client/scopes.
- [ ] Add expiration/refresh tests.

## File-Level Execution
- `src/lightbulb/services/access_token.gleam`
- `src/lightbulb/providers/data_provider.gleam`
- `src/lightbulb/providers/memory_provider.gleam`
- `src/lightbulb/tool.gleam`
- `test/lightbulb/services/access_token_test.gleam`
- `test/lightbulb/providers/...`
