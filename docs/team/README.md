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

## Product Invariant Gate

Every role must preserve Handrail as a free, local-first iOS remote control for Codex Desktop chats on the user's Mac. The canonical contract is [Handrail Product Invariants](../product-invariants.md).

Stop and record the product decision needed before implementing or claiming work that implies cloud relay, hosted execution, account state, payment, generic terminal behavior, multi-agent control, non-Codex agent support, or direct iOS file editing that bypasses Codex Desktop.

When a run touches product scope, protocol behavior, App Store evidence, or visible iPhone/iPad UI, the role report must include:

```markdown
## Product Invariant Check
```

The check should state whether the run preserved free, local-first, Codex Desktop-only Handrail and name any drift risk found.

## Coordination

The core team now runs as conventional independent Codex Desktop automations:

| Role | Schedule | Operating shape |
|---|---:|---|
| Handrail PM | Every 6 hours | Extensive product run; complete multiple concrete PM actions when they are independent and within PM ownership. |
| Handrail Architect | Every 6 hours | Extensive architecture run; inspect relevant boundaries and make concrete spec, test, code, or issue progress. |
| Handrail Lead Dev | Every hour | Complete or explicitly block one complete feature, bug, or hygiene target. |
| Handrail QA Lead | Every 3 hours | Validate the current QA handoff first, then the highest-value reproducible bug or regression evidence. |

The Business Analyst remains on its separate daily App Store eligibility cadence, and the simulator sweep remains a separate broad confidence check.

Roles coordinate through reports, GitHub issues, Slack requests, and handoff files. No role starts, schedules, or simulates another role. Normal product validation is different: a role may fully exercise Handrail functionality when the selected issue requires it, including creating a real local Codex Desktop chat through Handrail `start_chat`. If two roles identify conflicting next actions, the later role should record the conflict directly rather than resolving it silently.

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
- verification performed,
- the product invariant check when the run touches product scope, protocol behavior, App Store evidence, or visible iPhone/iPad UI.
