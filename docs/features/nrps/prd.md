# Product Requirements Document: nrps

## 1. Problem / User Value
NRPS support must handle spec-correct claim decoding, tolerant member parsing, and practical paging/filter workflows for real rosters.

## 2. Scope
### In scope
- NRPS claim model correction and tolerant decode behavior.
- Membership model updates for optional fields and defaults.
- Membership fetch options: role filter, limit, paging, differences, `rlid` support.

### Out of scope
- AGS and deep-linking features.

## 3. Requirements in Scope
- FR-NRPS-01
- FR-NRPS-02
- NFR-02
- NFR-04
- NFR-05

## 4. Success Criteria
- NRPS claims decode correctly across platform variants.
- Membership decode works with minimal valid payloads.
- Paging/filter/differences flows covered with tests.
