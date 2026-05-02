# Agent Task Team Configuration

## Overview

Handrail uses a recurring Codex agent task team to keep project work moving without turning every task into a manual conversation. Each agent has a narrow job, a local operating contract, a conventional schedule, and a required place to leave evidence.

The core team now runs as independent scheduled automations. There is no role-to-role launch chain.

## Current Team

| Role | Schedule | Status | Main responsibility |
|---|---:|---|---|
| Handrail PM | Every 6 hours | Active | Extensive product run: scope, sequencing, milestones, releases, and decision pressure. |
| Handrail Architect | Every 6 hours | Active | Extensive architecture run: system boundaries, protocol contracts, persistence assumptions, and specs. |
| Handrail Lead Dev | Every hour | Active | One complete feature, bug, or hygiene target per run. |
| Handrail QA Lead | Every 3 hours | Active | Targeted validation, bug triage, simulator evidence, and regression confidence. |
| Handrail Business Analyst | Daily at 9 AM | Active | App Store eligibility, submission artifacts, and release-readiness coordination. |
| Handrail QA Daily Simulator Sweep | Daily at 8 AM | Active | Broad iPhone/iPad simulator sweep and reproducible bug discovery. |

All current team roles use:

- Model: `gpt-5.5`
- Reasoning effort: `high`
- Execution environment: `local`
- Workspace: `/Users/velocityworks/IdeaProjects/handrail`
- GitHub repository target: `zfifteen/handrail`
- GitHub access path: local `gh` CLI only

## Coordination

Each role has a persona document in `docs/team/`. The persona document states what the role owns, what it reads, what it may change, and what evidence it must leave.

Roles coordinate through durable artifacts:

- Repo docs and role reports.
- GitHub issues, milestones, and releases.
- Handoff files under `$CODEX_HOME/automations/<role>/handoff.md`.
- Slack messages in `#handrail-agents` for role-addressed operational requests.

No role starts, schedules, or simulates another role. A role may write or refresh a handoff file for a later scheduled run, but it must not edit automation records or automation database rows as a handoff mechanism. Normal product validation is different: a role may fully exercise Handrail functionality when the selected issue requires it, including creating a real local Codex Desktop chat through Handrail `start_chat`.

The useful rhythm is:

1. PM clarifies useful product movement during a six-hour cadence.
2. Architect preserves boundaries and specs during a six-hour cadence.
3. Lead Dev completes or blocks one implementation target every hour.
4. QA Lead validates handoffs and bug evidence every three hours.
5. The daily simulator sweep handles broad confidence outside the core role cadence.

Lead Dev's work-selection priority remains addressed Slack request, Lead Dev handoff, concrete GitHub bug issue, concrete GitHub enhancement issue, then one hygiene patch.

## Business Analyst Track

The Business Analyst is separate from the core PM, Architect, Lead Dev, and QA cadence. It runs daily because App Store eligibility moves at a different pace than implementation.

The Business Analyst owns:

- Apple Developer Program and team assignment readiness.
- Signing, provisioning, entitlements, capabilities, and TestFlight readiness.
- App Store Connect metadata.
- Privacy policy, local network usage, notification declarations, and review notes.
- Store assets such as app icon, screenshots, listing copy, support URL, and marketing URL.
- Handoffs to PM, Architect, Lead Dev, or QA Lead when eligibility work needs a product decision, design decision, implementation patch, or validation evidence.

The Business Analyst can post Slack requests, but the durable record still belongs in repo docs, GitHub issues, or handoff files.

## Local Access

The team runs locally on the user's Mac. Each agent can work in the same project workspace:

```text
/Users/velocityworks/IdeaProjects/handrail
```

Local access includes:

- The Git working tree, including source code, tests, docs, and local uncommitted changes.
- Team role docs under `docs/team/`.
- Team reports under `docs/team/outputs/`.
- Codex automation definitions under `$CODEX_HOME/automations/`.
- Handoff files such as `$CODEX_HOME/automations/handrail-lead-dev/handoff.md`.
- Local build and test tools available to Codex, including shell commands, `gh`, Node, Xcode tooling, and simulator tooling when installed.

The roles are instructed to preserve unrelated local changes. They may edit code, tests, docs, and GitHub issues only when doing so is the smallest concrete action that advances their role.

## Remote Access

The team has access to remote services through local CLIs and configured Codex tools.

Current remote surfaces are:

- GitHub repository: `zfifteen/handrail`
- Slack channel: `#handrail-agents` (`C0B0K6B0T6K`)
- Apple-related submission work through local files, Xcode state, and any available account evidence

GitHub is used for durable issue, milestone, and release tracking. Automation prompts require the local `gh` CLI for GitHub reads and writes so unattended runs do not hit connector permission prompts. Slack is used for role-addressed coordination and visibility. Apple account work is treated carefully: if a step requires paid developer enrollment, App Store Connect access, certificates, hosted URLs, or human credentials, the role records that as a blocker instead of inventing a workaround.

## Slack Coordination

The Slack channel is an operational inbox, not the source of truth.

Every role checks recent messages in `#handrail-agents` at the start of its run and acts only on messages addressed to its exact role name:

- `Handrail PM`
- `Handrail Business Analyst`
- `Handrail Architect`
- `Handrail Lead Dev`
- `Handrail QA Lead`

Slack requests use this shape:

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

Before one role posts a Slack request to another role, it writes the durable artifact first when one is needed. A Slack request is handled only when the receiving role records the message `Subject` and timestamp in its report or durable handoff response. If Slack is unavailable, the team continues through handoff files and GitHub issues, then records the Slack blocker in the normal report.

## QA Validation Rhythm

QA Lead runs every three hours and performs targeted validation from the QA handoff first. Simulator validation remains mandatory for visible iPhone or iPad UI, navigation, decoded data feeding a screen, gestures, context menus, sheets, tabs, lists, and empty states. Non-UI docs, CLI, config, and automation-only changes do not require the full iPhone and iPad sweep unless the handoff requests it.

The daily simulator sweep is the broad release-confidence mechanism. It runs outside the core role cadence, saves evidence under `test-artifacts/`, and creates or updates GitHub bug issues only for reproducible findings.

## Durable Artifacts

The system works because each agent writes to places that later scheduled runs can inspect.

| Artifact | Purpose |
|---|---|
| `docs/team/*.md` | Role contracts. These define how each agent behaves. |
| `docs/team/outputs/*.md` | Latest role reports. These summarize findings, changes, blockers, and verification. |
| `$CODEX_HOME/automations/*/automation.toml` | Runtime automation configuration: prompt, schedule, model, status, and workspace. |
| `$CODEX_HOME/automations/*/handoff.md` | Direct handoff inboxes for concrete role-to-role requests. |
| GitHub issues | Durable work items, acceptance criteria, blockers, and evidence. |
| Slack messages | Human-visible role requests and coordination signals. |

The useful balance is:

```text
durable truth = repo docs + handoff files + GitHub issues
visible coordination = Slack
execution rhythm = conventional automation schedules
```

## Controls

| Risk | Control |
|---|---|
| Agents overwrite each other's work | Each role owns a different class of work and must preserve unrelated changes. |
| Slack becomes the only task record | Require durable artifacts before Slack requests and record handled Slack subject/timestamp. |
| Role prompts drift from docs | Make role docs the source of truth and keep automation prompts pointed back to them. |
| Handoffs are skipped for backlog work | Lead Dev must complete or explicitly block addressed Slack requests and handoff files before selecting GitHub issues. |
| QA misses UI regressions | QA Lead runs targeted validation every three hours and the daily simulator sweep owns broad release-confidence coverage. |
| Human-account work is faked | Account, certificate, App Store Connect, and hosted URL blockers must be stated plainly. |

## References

- Team overview: `docs/team/README.md`
- Business Analyst role: `docs/team/business-analyst.md`
- PM automation: `$CODEX_HOME/automations/handrail-pm/automation.toml`
- Architect automation: `$CODEX_HOME/automations/handrail-architect/automation.toml`
- Lead Dev automation: `$CODEX_HOME/automations/handrail-lead-dev/automation.toml`
- QA Lead automation: `$CODEX_HOME/automations/handrail-qa-lead/automation.toml`
- Business Analyst automation: `$CODEX_HOME/automations/handrail-business-analyst/automation.toml`
- Slack channel: `#handrail-agents` (`C0B0K6B0T6K`)
