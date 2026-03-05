# Execution Checklists

## Investigation Checklist

- Reproduce issue with concrete inputs.
- Capture expected vs actual behavior.
- Narrow fault domain (backend, frontend, integration, data).
- Prove or disprove top hypotheses with evidence.
- Identify minimal safe fix and regression risks.

## Small Change Checklist

- Confirm scope boundaries and non-goals.
- Update only required modules/routes/components.
- Add or update focused tests.
- Validate public interfaces and backward compatibility.
- Verify logs/errors/telemetry remain actionable.

## Feature Delivery Checklist

- Read `prd.md`, `fdd.md`, and `plan.md` in order.
- Map requirements to implementation units and tests.
- Implement in plan order unless blockers force resequencing.
- Validate acceptance criteria from the PRD.
- Verify UX/API/integration behavior end-to-end.

## LTI/LMS Checklist

- Validate launch and auth flow assumptions.
- Confirm required claims/roles/context fields are handled.
- Check course/user identifiers and tenancy boundaries.
- Verify grade/assignment semantics where applicable.
- Confirm failure modes return clear, supportable errors.
