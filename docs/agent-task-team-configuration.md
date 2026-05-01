# Agent Task Team Configuration

## Overview

Handrail uses a recurring Codex agent task team to keep project work moving without turning every task into a manual conversation. Each agent has a narrow job, a local operating contract, a schedule or one visible downstream run-now action, and a required place to leave evidence.

The current team has three entry points:

- The PM runs every three hours and starts the implementation chain.
- The Business Analyst runs once a day at 9 AM and manages App Store eligibility.
- The QA daily simulator sweep runs once a day at 8 AM and gathers broad release-confidence evidence.

The implementation chain is:

```text
Handrail PM
  -> Handrail Architect
    -> Handrail Lead Dev
      -> Handrail QA Lead
```

The PM is the only active three-hour cron job in that chain. Architect, Lead Dev, and QA Lead are paused as cron jobs and are run one at a time by the previous role through the Handrail CLI helper that uses Codex Desktop's normal IPC path. This creates normal visible automation threads while preventing several agents from independently changing the same project at the same time. The daily simulator sweep is a QA confidence sidecar, not part of the PM handoff chain.

The invariant is simple: one role advances one kind of work, writes durable evidence, hands off the next concrete request, and then runs at most one downstream role when appropriate.

## Current Team

| Role | Schedule | Status | Main responsibility |
|---|---:|---|---|
| Handrail PM | Every 3 hours | Active | Product scope, sequencing, milestones, releases, and decision pressure. |
| Handrail Architect | Run by PM | Paused cron | System boundaries, protocol contracts, persistence assumptions, and specs. |
| Handrail Lead Dev | Run by Architect | Paused cron | Narrow implementation patches, reviewability, tests, and QA handoff. |
| Handrail QA Lead | Run by Lead Dev | Paused cron | Behavioral evidence, bug triage, simulator validation, and regression confidence. |
| Handrail Business Analyst | Daily at 9 AM | Active | App Store eligibility, submission artifacts, and release-readiness coordination. |
| Handrail QA Daily Simulator Sweep | Daily at 8 AM | Active | Broad iPhone/iPad simulator sweep and reproducible bug discovery. |

All current team roles use:

- Model: `gpt-5.5`
- Reasoning effort: `high`
- Execution environment: `local`
- Workspace: `/Users/velocityworks/IdeaProjects/handrail`
- GitHub repository target: `zfifteen/handrail`

## How The Handoff Chain Works

Each role has a persona document in `docs/team/`. The persona document states what the role owns, what it reads, what it may change, and what evidence it must leave.

The PM automation runs on a timer. At the end of the PM run, it runs only Architect with the helper command:

```sh
node /Users/velocityworks/IdeaProjects/handrail/scripts/run-codex-automation-now.mjs handrail-architect
```

The helper sends the Codex Desktop `automation-run-now` IPC request. It does not call app-server thread creation paths, edit automation state, edit database rows, create detached workers, or mark any run successful. If Desktop rejects the IPC request, the role records the exact error as a blocker and stops.

The Architect runs Lead Dev only when downstream implementation work exists. When the Architect finds a structural implementation task, it writes a concrete Lead Dev handoff and runs only `handrail-lead-dev` with:

```sh
node /Users/velocityworks/IdeaProjects/handrail/scripts/run-codex-automation-now.mjs handrail-lead-dev
```

If the Architect finds no structural implementation task but concrete GitHub `bug` or `enhancement` issues need work, it writes a neutral Lead Dev handoff instructing Lead Dev to select work by its deterministic order, then runs only Lead Dev. If neither condition exists, the Architect records `No downstream handoff` and runs no downstream role.

The Lead Dev writes a QA handoff after implementation work, then runs only `handrail-qa-lead` with:

```sh
node /Users/velocityworks/IdeaProjects/handrail/scripts/run-codex-automation-now.mjs handrail-qa-lead
```

No role may run more than one downstream role from a single run. Downstream automations remain paused in their automation records; the run-now helper creates the visible thread directly.

This gives the team a deterministic rhythm:

1. PM chooses or clarifies useful product movement.
2. Architect translates product pressure into a boundary or contract decision.
3. Architect runs Lead Dev only when there is a concrete downstream implementation task or a concrete implementation issue queue.
4. Lead Dev makes one narrow implementation move selected by handoff-first priority.
5. QA Lead verifies behavior and records evidence.
6. The cycle repeats on the next PM run.

Lead Dev's work-selection priority is addressed Slack request, Lead Dev handoff, concrete GitHub bug issue, concrete GitHub enhancement issue, then one hygiene patch.

## Business Analyst Track

The Business Analyst is separate from the three-hour implementation chain. It runs daily because App Store eligibility moves at a different pace than code implementation.

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
- The Handrail run-now helper at `scripts/run-codex-automation-now.mjs`.
- Local build and test tools available to Codex, including shell commands, `gh`, Node, Xcode tooling, and simulator tooling when installed.

The roles are instructed to preserve unrelated local changes. They may edit code, tests, docs, and GitHub issues only when doing so is the smallest concrete action that advances their role.

## Remote Access

The team has access to remote services through configured Codex tools and local CLIs.

Current remote surfaces are:

- GitHub repository: `zfifteen/handrail`
- Slack channel: `#handrail-agents` (`C0B0K6B0T6K`)
- Apple-related submission work through local files, Xcode state, and any available account evidence

GitHub is used for durable issue, milestone, and release tracking. Slack is used for role-addressed coordination and visibility. Apple account work is treated carefully: if a step requires paid developer enrollment, App Store Connect access, certificates, hosted URLs, or human credentials, the role records that as a blocker instead of inventing a workaround.

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

Run-now QA runs perform targeted validation from the QA handoff first. Simulator validation remains mandatory for visible iPhone or iPad UI, navigation, decoded data feeding a screen, gestures, context menus, sheets, tabs, lists, and empty states. Non-UI docs, CLI, config, and automation-only changes do not require the full iPhone and iPad sweep unless the handoff requests it.

The daily simulator sweep is the broad release-confidence mechanism. It runs outside the PM -> Architect -> Lead Dev -> QA chain, saves evidence under `test-artifacts/`, and creates or updates GitHub bug issues only for reproducible findings.

## Durable Artifacts

The system works because each agent writes to places that the next run can inspect.

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
execution rhythm = automation schedules + one visible downstream run-now action
```

## Why This Is Plugin-Shaped

This configuration can become a generalized Codex plugin because the pattern is not specific to Handrail. A plugin could scaffold the same pieces for any project:

- A team definition file that lists roles, responsibilities, schedules, and handoff paths.
- A set of role persona templates.
- A shared Slack protocol.
- Automation prompts generated from the role definitions.
- One visible downstream run-now action per upstream role, with conditional downstream execution.
- A report directory and output contract.
- Optional GitHub issue and milestone conventions.

The plugin should avoid making the team "smart" in too many ways. The value comes from a small number of stable rules:

- One role owns one class of decisions.
- One run chooses one narrow action, with handoffs taking priority over unrelated backlog work.
- Each action leaves evidence.
- Cross-role requests are addressed explicitly.
- Slack improves visibility but does not replace durable state.
- Run-now agents inherit the configured prompt, model, and reasoning effort from their own automation records.
- QA uses targeted validation for handoffs and a separate daily simulator sweep for broad confidence.

## Generalized Plugin Implementation Plan

### Objective

Create a Codex plugin that can install a project-specific agent task team from a small configuration file. The plugin should make it easy to define roles, schedules, handoff paths, Slack channel, repository target, and output reports without manually editing every automation prompt.

### Phase 1: Template Extraction

Extract the Handrail pattern into reusable templates:

- `team/README.md` template for shared rules and Slack coordination.
- Role persona templates for PM, Architect, Lead Dev, QA Lead, and Business Analyst.
- Automation prompt template with placeholders for role name, repo path, GitHub target, Slack channel, report path, handoff path, and downstream automation id.
- Downstream run-now instructions that call the project helper with exactly one downstream automation id.

Validation:

- Generate a team into a temporary project directory.
- Confirm all generated Markdown files use LF line endings.
- Confirm generated run-now instructions name exactly one downstream role per upstream role.

### Phase 2: Configuration Schema

Define a minimal team configuration file.

The first version only needs:

- Project name.
- Project path.
- GitHub repository target.
- Slack channel id and display name.
- Roles with exact names, schedules, statuses, report paths, and handoff paths.
- Chain order for scheduled roles, including conditional downstream policy.
- Model and reasoning effort defaults.

Do not add multiple scheduling modes, alternate communication backends, or complex dependency graphs in the first version.

Validation:

- Load one Handrail-equivalent config.
- Fail clearly when a required field is missing.
- Generate identical role names, schedules, and chain order to the current Handrail setup.

### Phase 3: Installer Command

Add a plugin workflow that creates or updates:

- Team docs in the target repo.
- Automation TOML records in `$CODEX_HOME/automations/`.
- Optional initial handoff files.

The installer should prefer explicit replacement of known generated blocks over broad rewriting. It should state what it changed and stop if existing non-generated content would be overwritten.

Validation:

- Run installer against a test project.
- Inspect generated automations with TOML parsing.
- Confirm active and paused statuses match the config.

### Phase 4: Operational Verification

Verify the installed team can operate.

Checks:

- Slack channel can be read.
- Optional test post can be sent after user approval.
- GitHub target can be reached.
- The first active automation can see its role doc and report path.
- Downstream run-now actions create exactly one visible Codex Desktop automation thread and leave other downstream roles paused.

For UI or mobile projects, the plugin should not claim validation is complete unless the project-specific QA role performs the required simulator or device checks.

## Risks And Controls

| Risk | Control |
|---|---|
| Agents overwrite each other's work | Keep only the first chain role active; run downstream roles sequentially and conditionally. |
| Slack becomes the only task record | Require durable artifacts before Slack requests and record handled Slack subject/timestamp. |
| Role prompts drift from docs | Make role docs the source of truth and keep automation prompts short enough to point back to them. |
| Downstream roles ignore configured reasoning effort | The helper reads the prompt, model, and reasoning effort from the downstream automation record. |
| Handoffs are skipped for backlog work | Lead Dev must complete or explicitly block addressed Slack requests and handoff files before selecting GitHub issues. |
| QA spends every run-now QA thread on broad sweeps | Run-now QA threads validate the handoff; daily simulator sweep owns broad regression discovery. |
| A generalized plugin becomes too abstract | Start with one deterministic chain and one daily sidecar role. Add new shapes only after a real project needs them. |
| Human-account work is faked | Account, certificate, App Store Connect, and hosted URL blockers must be stated plainly. |

## References

- Team overview: `docs/team/README.md`
- Business Analyst role: `docs/team/business-analyst.md`
- PM automation: `$CODEX_HOME/automations/handrail-pm/automation.toml`
- Business Analyst automation: `$CODEX_HOME/automations/handrail-business-analyst/automation.toml`
- Slack channel: `#handrail-agents` (`C0B0K6B0T6K`)
