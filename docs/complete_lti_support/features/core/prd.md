# Product Requirements Document: core

## 1. Problem / User Value
Lightbulb must provide certification-grade LTI Core 1.3 launch handling. Current gaps in claim validation, audience handling, target link consistency, and nonce semantics can cause security and interoperability failures.

## 2. Scope
### In scope
- Required claim validation and message-type-aware launch validation.
- `aud` / `azp` handling for registration resolution.
- Login state and `target_link_uri` consistency checks.
- Nonce hardening (expiration + one-time use).

### Out of scope
- Deep Linking response generation.
- AGS/NRPS service APIs.

## 3. Requirements in Scope
- FR-CORE-01
- FR-CORE-02
- FR-CORE-03 (Core handling aspects)
- FR-PROV-01 (Core launch semantics)
- NFR-01
- NFR-02
- NFR-03
- NFR-04

## 4. Success Criteria
- Required Core claim checks implemented and tested.
- Launch validation supports valid audience forms.
- Target-link consistency and nonce semantics enforced.
- Core bad-payload conformance cases covered in tests.
