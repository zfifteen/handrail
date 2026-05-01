# Handrail Virtual Project Team

This directory defines the recurring virtual project team for Handrail. Each role is a concrete operating contract, not a loose style prompt. The persona documents are the source of truth for how each automation should inspect the project, choose work, modify artifacts, and leave evidence.

## Team Members

- [PM](pm.md): owns scope, sequencing, product value, and decision pressure.
- [Business Analyst](business-analyst.md): owns App Store eligibility, submission artifacts, and release-readiness coordination.
- [Architect](architect.md): owns system boundaries, invariants, protocol shape, and spec drift.
- [QA Lead](qa-lead.md): owns behavioral evidence, regression risk, and simulator validation.
- [Lead Dev](lead-dev.md): owns narrow implementation, code reviewability, and completion discipline.

## Shared Operating Rules

Every role must work from the current local workspace in `/Users/velocityworks/IdeaProjects/handrail` and preserve unrelated user changes. A role may edit code, tests, docs, and GitHub issues when doing so is the smallest concrete action that advances its responsibility.

The team uses `zfifteen/handrail` as the GitHub repository target. GitHub issues are work artifacts, not commentary: create or update an issue only when the project would benefit from durable tracking, decision capture, or follow-up outside the current run.

Each run should prefer one narrow, deterministic path. Do not add fallback workflows, broad frameworks, or speculative future-proofing. If a role cannot complete the needed action with the available context and tools, it should state the blocker plainly in its output.

## Coordination

The PM run starts the sequential implementation chain: PM -> Architect -> Lead Dev -> QA Lead. The Business Analyst runs daily and owns App Store eligibility coordination. Each role should read any relevant prior outputs before choosing work. If two roles identify conflicting next actions, the later role should record the conflict directly rather than resolving it silently.

The implementation chain must use the Handrail run-now helper so every downstream role is requested through Codex Desktop's normal visible automation run-now path. PM runs only Architect. Architect runs only Lead Dev when its downstream rules call for implementation. Lead Dev runs only QA Lead after implementation work and a QA handoff. Architect, Lead Dev, and QA Lead remain paused by default in their automation records.

The helper command is:

```sh
node /Users/velocityworks/IdeaProjects/handrail/scripts/run-codex-automation-now.mjs <automation-id>
```

It sends the Codex Desktop `automation-run-now` IPC request. It does not call app-server thread creation paths, edit automation state, edit database rows, or create a background worker. If the helper fails, record the exact error as a blocker and stop. Do not use a fallback handoff mechanism.

## Slack Coordination

The team uses `#handrail-agents` (`C0B0K6B0T6K`) as a role-addressed coordination channel. Slack is an operational inbox and visibility layer; durable state still belongs in handoff files, GitHub issues, and role reports.

At the start of every run, each role must inspect recent Slack messages in `#handrail-agents` addressed to its exact role name:

- `Handrail PM`
- `Handrail Business Analyst`
- `Handrail Architect`
- `Handrail Lead Dev`
- `Handrail QA Lead`

A Slack request should use this shape:

```text
From: Handrail Business Analyst
To: Handrail QA Lead
Subject: Verify Release archive local network usage description

Request:
Verify that the Release archive Info.plist contains NSLocalNetworkUsageDescription.

Durable artifact:
$CODEX_HOME/automations/handrail-qa-lead/handoff.md

Evidence needed:
exact command, archive path inspected, extracted Info.plist result, pass/fail conclusion
```

Roles should act only on messages where `To:` matches their exact role name. A Slack request is handled only when the receiving role records the Slack `Subject` and message timestamp in its report or durable handoff response. Before posting a Slack request to another role, write the durable artifact first when one is needed. Post to Slack only for concrete cross-role requests, not routine run summaries. If Slack is unavailable, record that blocker in the normal report and continue with file/GitHub coordination.

## Outputs

Role outputs belong under [outputs](outputs/README.md) when a run produces a report. Reports are stable project artifacts; code changes, tests, docs, and GitHub issues are also valid outputs when they are the appropriate human-equivalent action for the role.

Each output must state:

- the strongest supported finding or action,
- exact files, tests, commands, or issues touched,
- remaining blocker or next action,
- verification performed.
