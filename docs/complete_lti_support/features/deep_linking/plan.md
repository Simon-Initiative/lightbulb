# Implementation Plan: deep_linking

## Phase 1: Request Model Support
- [ ] Add deep-link settings type + decoder.
- [ ] Wire `LtiDeepLinkingRequest` into launch message validation.
- [ ] Add request decoding tests.

## Phase 2: Response JWT + Content Items
- [ ] Implement content-item models/builders.
- [ ] Implement deep-link response claim builder and signer.
- [ ] Add data-echo and required-claim tests.

## Phase 3: Form Post + Conformance Coverage
- [ ] Add helper for auto-submit form post with `JWT` field.
- [ ] Add integration/conformance tests for end-to-end response contract.
- [ ] Document usage patterns.

## File-Level Execution
- `src/lightbulb/deep_linking.gleam`
- `src/lightbulb/deep_linking/settings.gleam`
- `src/lightbulb/deep_linking/content_item.gleam`
- `src/lightbulb/tool.gleam`
- `test/lightbulb/...`
