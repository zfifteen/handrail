# Handrail Virtual Project Team

This directory defines the recurring virtual project team for Handrail. Each role is a concrete operating contract, not a loose style prompt. The persona documents are the source of truth for how each automation should inspect the project, choose work, modify artifacts, and leave evidence.

## Team Members

- [PM](pm.md): owns scope, sequencing, product value, and decision pressure.
- [Architect](architect.md): owns system boundaries, invariants, protocol shape, and spec drift.
- [QA Lead](qa-lead.md): owns behavioral evidence, regression risk, and simulator validation.
- [Lead Dev](lead-dev.md): owns narrow implementation, code reviewability, and completion discipline.

## Shared Operating Rules

Every role must work from the current local workspace in `/Users/velocityworks/IdeaProjects/handrail` and preserve unrelated user changes. A role may edit code, tests, docs, and GitHub issues when doing so is the smallest concrete action that advances its responsibility.

The team uses `zfifteen/handrail` as the GitHub repository target. GitHub issues are work artifacts, not commentary: create or update an issue only when the project would benefit from durable tracking, decision capture, or follow-up outside the current run.

Each run should prefer one narrow, deterministic path. Do not add fallback workflows, broad frameworks, or speculative future-proofing. If a role cannot complete the needed action with the available context and tools, it should state the blocker plainly in its output.

## Coordination

All four roles run every three hours. They act independently, but each role should read any relevant prior outputs before choosing work. If two roles identify conflicting next actions, the later role should record the conflict directly rather than resolving it silently.

## Outputs

Role outputs belong under [outputs](outputs/README.md) when a run produces a report. Reports are stable project artifacts; code changes, tests, docs, and GitHub issues are also valid outputs when they are the appropriate human-equivalent action for the role.

Each output must state:

- the strongest supported finding or action,
- exact files, tests, commands, or issues touched,
- remaining blocker or next action,
- verification performed.
