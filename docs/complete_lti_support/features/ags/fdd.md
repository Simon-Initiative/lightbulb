# Functional Design Document: ags

## 1. Functional Scope
- CRUD and query operations for line items.
- Results retrieval with filter support.
- Score posting behavior with strict media-type/response handling.
- Scope-aware operation guards.
- Paging metadata extraction from Link headers.

## 2. Functional Architecture
### Public API
- Expand AGS module API to expose complete operations and typed models.
- Introduce `Result` type and expanded `LineItem` shape.

### Internal Design
- Shared request/header utilities across AGS operations.
- Shared Link-header parser for paginated containers.
- Scope predicates for each operation category.

### Compatibility
- Maintain existing helper pathways where possible; add wrappers as needed.

## 3. Runtime Flow
1. Parse launch AGS claim and resolve operation permissions by scope.
2. Execute requested line item/score/result operation.
3. Parse payload and paging links.
4. Return typed result with deterministic errors.

## 4. Error Semantics
- Scope denial and malformed endpoint errors are explicit.
- Decode errors include operation context.
- Pagination parsing failures degrade gracefully.

## 5. Testability Design
- Unit coverage for each operation and decoder.
- Integration coverage for paginated flows.
- Negative tests for scope insufficiency and malformed responses.
