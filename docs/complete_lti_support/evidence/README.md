# Certification Evidence Package

This directory stores domain-level evidence artifacts referenced by the conformance matrix.

## Required Per-Record Fields

- `validator_test_id` (or internal objective identifier)
- `execution_datetime_utc`
- `environment_commit_sha`
- `request_response_excerpts` (redacted)
- `disposition` (`pass` or `fail`)
- `notes` (include remediation link for failures)

## Directory Layout

- `core/`
- `nrps/`
- `ags/`
- `deep_linking/`
- `summary.md`
