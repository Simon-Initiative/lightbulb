# Implementation Plan: nrps

## Phase 1: Claim Model Correction
- [ ] Update NRPS claim type and decoder to spec-aligned required fields.
- [ ] Add tolerant optional handling.
- [ ] Add claim decode tests.

## Phase 2: Membership Model Tolerance
- [ ] Update membership type for optional profile fields/default status.
- [ ] Update decoders/callers.
- [ ] Add compatibility notes/tests for type changes.

## Phase 3: Paging and Filter APIs
- [ ] Add `fetch_memberships_with_options`.
- [ ] Add role/limit/paging/differences/`rlid` logic.
- [ ] Add paginated roster and malformed-link tests.

## File-Level Execution
- `src/lightbulb/services/nrps.gleam`
- `src/lightbulb/services/nrps/membership.gleam`
- `src/lightbulb/http/link_header.gleam`
- `test/lightbulb/services/nrps_test.gleam`
