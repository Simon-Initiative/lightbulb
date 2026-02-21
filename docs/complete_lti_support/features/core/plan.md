# Implementation Plan: core

## Phase 1: Claim Validation Hardening
- [ ] Implement required claim checks by message type.
- [ ] Enforce LTI version requirements and claim shape validation.
- [ ] Add tests for missing/invalid claims.

## Phase 2: Audience Resolution
- [ ] Support `aud` as string and list.
- [ ] Add `azp` decision rules and deterministic registration resolution.
- [ ] Add positive/negative audience fixture coverage.

## Phase 3: State + Target Link Consistency
- [ ] Extend provider semantics for login context persistence/retrieval.
- [ ] Persist login context at OIDC login flow.
- [ ] Enforce launch `target_link_uri` consistency with stored context.

## Phase 4: Nonce Hardening
- [ ] Enforce nonce expiration during validation (not cleanup-only).
- [ ] Preserve one-time-use semantics.
- [ ] Add replay and TTL boundary tests.

## File-Level Execution
- `src/lightbulb/tool.gleam`
- `src/lightbulb/providers/data_provider.gleam`
- `src/lightbulb/providers/memory_provider.gleam`
- `test/lightbulb/...`

## Verification
- Unit: claim checks, audience parsing, nonce semantics.
- Integration: OIDC login->launch state + target-link flow.
- Negative/security: replay, mismatched audience, wrong/missing claims.
