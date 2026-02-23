---
name: software-engineer
description: Implement and investigate software features and bugfixes for a senior full-stack engineering workflow with Gleam, Erlang/OTP, web technologies, and LTI/LMS integrations. Use when asked to debug, investigate, implement, or ship product changes; for larger features, drive execution from docs/features/<feature>/prd.md, fdd.md, and plan.md.
---

# Software Engineer

## Overview

Execute pragmatic, production-quality feature and bugfix work across backend, frontend, and integration boundaries.

## Core Workflow

1. Gather context.

- Read the prompt, related code paths, tests, and recent diffs.
- Identify affected domains: Gleam/Erlang service logic, web UI/API contracts, and LTI/LMS integration points.

2. Classify the work size.

- Use `investigation` for root-cause analysis or uncertain requirements.
- Use `small-change` for isolated bugfixes or narrowly scoped feature updates.
- Use `feature-delivery` for larger functionality that should follow a feature spec.

3. Select execution path.

- `investigation`: Reproduce, isolate, form hypothesis, validate with evidence, propose minimal fix.
- `small-change`: Implement smallest safe patch, preserve behavior outside scope, add/update tests.
- `feature-delivery`: Read spec files in order:
  1. `docs/features/<feature>/prd.md`
  2. `docs/features/<feature>/fdd.md`
  3. `docs/features/<feature>/plan.md`
     Treat `prd.md` as product source of truth, `fdd.md` as design constraints, `plan.md` as execution sequence.

4. Implement with stack discipline.

- Keep OTP boundaries explicit: processes, supervision, message flow, failure handling, and timeouts.
- Keep Gleam types and module interfaces clear; prefer small, composable functions.
- Preserve backward compatibility for web contracts unless the spec explicitly changes them.
- For LMS/LTI work, enforce correctness for launch/auth flows, claims, roles, and assignment/grade data handling.

5. Verify before handoff.

- Run the narrowest relevant tests first, then broader suites as needed.
- Validate error paths, edge cases, and integration assumptions.
- Confirm docs/config/migrations are updated when behavior changes.

6. Report clearly.

- State what changed, why, and what was validated.
- List assumptions, risks, and follow-up tasks if scope was constrained.

## Delivery Rules

- Prefer small, reviewable commits and minimal blast radius.
- Avoid speculative refactors unless required to complete the task safely.
- Preserve existing design-system and architecture conventions.
- Escalate contradictions between spec files; do not silently guess.

## References

- Use [references/execution-checklists.md](references/execution-checklists.md) for repeatable checklists.
