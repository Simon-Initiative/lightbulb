# Implementation Plan: ags

## Phase 1: Line Item Service Completion
- [ ] Expand `LineItem` model with optional spec fields.
- [ ] Add line item get/list/update/delete APIs.
- [ ] Keep/create compatibility wrappers around existing helper behavior.

## Phase 2: Result Service Completion
- [ ] Add `Result` model + decoder.
- [ ] Implement `list_results` with filter support.
- [ ] Add result decode and request tests.

## Phase 3: Scope Guards + Paging
- [ ] Add missing AGS scope constants and operation predicates.
- [ ] Implement shared Link-header parser.
- [ ] Integrate paging across list operations.

## Phase 4: Score Service Hardening + Conformance
- [ ] Validate score request/headers/response handling.
- [ ] Add negative-path coverage for media-type/status variants.
- [ ] Update documentation and conformance mappings.

## File-Level Execution
- `src/lightbulb/services/ags.gleam`
- `src/lightbulb/services/ags/line_item.gleam`
- `src/lightbulb/services/ags/result.gleam`
- `src/lightbulb/http/link_header.gleam`
- `test/lightbulb/services/ags_test.gleam`
