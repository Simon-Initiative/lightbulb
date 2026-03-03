# Certification Runbook

This runbook defines repeatable execution for internal pre-flight and validator-facing certification evidence.

## Preconditions And Environment Setup

- Required tooling:
  - Erlang/OTP `27.1.2`
  - Gleam `1.10.0`
- Required repository state:
  - clean working tree for dry-run execution evidence
  - up-to-date `docs/complete_lti_support/conformance_matrix.md`
- Required commands:
  - `gleam deps download`
  - `scripts/lint_conformance_matrix.sh`
  - `gleam test`

## Registration And Deployment Setup Checklist

- Confirm platform registration exists for the target LMS issuer/client pair.
- Confirm deployment IDs mapped in test fixtures are valid for launch validation scenarios.
- Confirm signing key/JWKS retrieval path is valid in provider configuration.
- Confirm nonce and login-context persistence providers are reachable.

## Endpoint Mapping Checklist

- OIDC login initiation endpoint is reachable and records login context.
- Launch validation endpoint accepts `id_token` and `state` and returns deterministic errors.
- AGS line item, score, and result service URLs resolve with expected auth scopes.
- NRPS memberships endpoint resolves with expected auth scope.
- Deep Linking return URL endpoint accepts form-post `JWT`.

## Protocol Execution Order

Execute in this order:

1. Core launch flow (OIDC login + launch validation, positive and negative).
2. NRPS flow (claim decode, scope guard, memberships retrieval/paging).
3. AGS flow (scope guard, line item operations, score publish, results retrieval).
4. Deep Linking flow (settings decode, response JWT build/sign, form-post payload).

## Test Account And Data Requirements

- One instructor account and one learner account in LMS test tenant.
- Course/context with:
  - at least one resource link
  - AGS enabled
  - NRPS enabled
- Tool registration with deployment enabled for the test context.

## Failure Triage Playbook

- If `scripts/lint_conformance_matrix.sh` fails:
  - fix missing schema values, requirement coverage, or broken refs before rerun.
- If a conformance test fails:
  - identify matrix row via `test_refs`
  - open remediation task and link it in evidence notes
  - rerun `gleam test` after fix and update `last_verified_date`.
- If validator dry-run fails:
  - capture request/response excerpts with redaction
  - map failure to requirement row(s)
  - keep row at `implemented` until rerun passes.

## Submission And Evidence Packaging Checklist

- `docs/complete_lti_support/conformance_matrix.md` is current.
- All in-scope rows are `verified` or have tracked remediation links.
- `docs/complete_lti_support/evidence/summary.md` is updated.
- Domain evidence files exist under:
  - `docs/complete_lti_support/evidence/core/`
  - `docs/complete_lti_support/evidence/nrps/`
  - `docs/complete_lti_support/evidence/ags/`
  - `docs/complete_lti_support/evidence/deep_linking/`

## Dry-Run Procedure Template

Copy this block into a dated evidence file for each run:

```md
# Dry Run: YYYY-MM-DD

- validator_test_id: <id or internal objective>
- execution_datetime_utc: <ISO timestamp>
- environment_commit_sha: <git sha>
- commands:
  - scripts/lint_conformance_matrix.sh
  - gleam test
- request_response_excerpts: <redacted summary>
- disposition: pass|fail
- notes: <links to remediation tasks if needed>
```

## Ownership Model

- Matrix steward: `lightbulb-maintainers`
- Feature owners update rows during implementation.
- Release owner validates `verified` rows and evidence freshness at cut time.
