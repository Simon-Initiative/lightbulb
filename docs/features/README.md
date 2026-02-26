# Feature Specifications

Each feature is organized by lowercase slug under `docs/complete_lti_support/features/`.

## Directory Contract
Each feature directory contains:
- `prd.md` (product requirements specification)
- `fdd.md` (functional design document)
- `plan.md` (phased implementation plan for end-to-end delivery)

## Error Modeling Guidance

- Feature docs should specify explicit typed error models (enums/variants/records),
  not dot-separated string error IDs.
- If compatibility string output is needed, specify a dedicated conversion helper.

## Features
- `core/`
- `deep_linking/`
- `ags/`
- `nrps/`
- `oauth_provider/`
- `certification/`
