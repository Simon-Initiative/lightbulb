# Functional Design Document: nrps

## 1. Functional Scope
- Decode NRPS claims (`context_memberships_url`, `service_versions`) with optional tolerance.
- Decode membership entries with required minimums + optional profile fields.
- Provide options-driven membership retrieval and paging traversal support.

## 2. Functional Architecture
### Public API
- Preserve base fetch API.
- Add options-based fetch API and paging metadata.

### Internal Design
- Use typed claim + membership models with defaults.
- Reuse shared Link-header parser.
- Build query parameters from options safely.

### Compatibility
- Existing `fetch_memberships` remains convenience wrapper.

## 3. Runtime Flow
1. Parse NRPS claim from launch.
2. Build request URL with optional filters.
3. Fetch and decode memberships.
4. Parse paging/differences links and return typed result.

## 4. Error Semantics
- Invalid claim/member shape errors are explicit.
- Paging-link parsing errors are surfaced with context or gracefully handled.

## 5. Testability Design
- Unit tests for claim/member decoding and option query construction.
- Integration tests for multi-page membership workflows.
- Negative tests for malformed payloads and link headers.
