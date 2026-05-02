# PM Report

## Strongest Product Finding

The iPhone App Store package had a claim/evidence mismatch: the v1 metadata marketed approval-response support and required an approval screenshot while #2 still blocks first-class Desktop approval routing. I narrowed the v1 iPhone listing and screenshot plan so milestone 1 stays a submission-evidence milestone instead of silently depending on #2.

## Decisions Or Issues Updated

- Slack inbox: checked `#handrail-agents` (`C0B0K6B0T6K`); no message was addressed to `Handrail PM`. The only channel request remains the no-action coordination verification at `2026-04-30 19:11:51 EDT` / TS `1777590711.698899`.
- Handoff inbox: no PM handoff file was present at `/Users/velocityworks/.codex/automations/handrail-pm/handoff.md`.
- GitHub auth: `gh auth status` is authenticated as `zfifteen`; all GitHub reads/writes used the local `gh` CLI.
- Updated `store-assets/metadata.txt` to remove approval-response support from the v1 iPhone description and add an explicit scope exclusion until #2 has first-class approval-routing evidence.
- Updated `store-assets/screenshot-plan.md` so the required v1 shot list is Dashboard, Chats list, Chat Detail, and New Chat. The approval screenshot is deferred until #2 and #29 produce real local Desktop approval evidence.
- Updated `docs/production_readiness_report.md` with the 2026-05-02 PM scope refresh: #29 has a reported local source patch but still needs live server restart/acceptance, and #28 no longer requires or markets approval-response evidence for v1.
- Updated GitHub milestone 1, `iPhone App Store readiness`, to record that approval-response marketing/screenshot evidence is deferred until #2.
- Commented on GitHub issue #28 with the narrowed acceptance gaps: https://github.com/zfifteen/handrail/issues/28#issuecomment-4363016759.
- No GitHub release was created or updated; `gh release list --repo zfifteen/handrail --limit 20` returned no releases.
- No Slack request was posted because the durable issue, milestone, and report updates carry the decision boundary.

## Scope Risks

- #25 remains externally blocked on a production-capable distribution/TestFlight/App Store provisioning profile for `com.velocityworks.Handrail` with Push Notifications and `aps-environment`.
- #26 remains externally blocked on choosing and publishing a stable hosted privacy policy URL for `docs/privacy-policy.md`.
- #28 now has a narrower closure contract: hosted privacy URL, final metadata URL replacement, and four verified v1 iPhone screenshots under `store-assets/screenshots/iphone/`.
- #29 remains open. The current branch reportedly contains the patched app-server `thread/start` + `turn/start` path, but the live Handrail listener on `127.0.0.1:8788` is still the old process and still fails through `thread-follower-start-turn`.
- #2 remains required before Handrail markets approval responses or submits an approval screenshot.
- The workspace was already dirty with source, docs, reports, tests, store assets, and QA artifacts. This PM run preserved unrelated local changes and changed only PM/readiness/store-asset documentation plus GitHub issue/milestone state.

## Next Product Action

Restart the live Handrail server outside this automation sandbox so it runs the rebuilt patched `cli/dist`, then rerun #29 acceptance: one real local `start_chat` must emit `chat_started`, emit a chat-linked `chat_event`, and appear in `node cli/dist/src/index.js chats` as the same Desktop-visible `codex:` chat.

## Product Invariant Check

- Preserved free, local-first, Codex Desktop-only Handrail: yes.
- Drift risk found: approval-response App Store copy was ahead of verified Desktop approval routing. The run removed that public claim from v1 artifacts instead of expanding scope or fabricating evidence.

## Verification

- Read role contracts: `docs/team/pm.md` and `docs/team/README.md`.
- Read PM automation memory at `/Users/velocityworks/.codex/automations/handrail-pm/memory.md`.
- Checked PM handoff path and found no handoff file.
- Checked Slack channel `C0B0K6B0T6K` for messages addressed to `Handrail PM`.
- Checked local state with `git status --short`; branch is `main` with existing unrelated local modifications.
- Reviewed project/product state: `README.md`, `docs/product-invariants.md`, `FEATURE_ROADMAP.md`, `TEST_PLAN.md`, `UI_PATHS.md`, `UI_PATH_ISSUES.md`, `docs/production_readiness_report.md`, `store-assets/metadata.txt`, `store-assets/screenshot-plan.md`, and current team outputs.
- Reviewed GitHub state with local `gh`: open issues, closed milestone issues, milestones, releases, and issues #2, #3, #25, #26, #28, and #29.
- Updated milestone 1 through `gh api repos/zfifteen/handrail/milestones/1 -X PATCH`.
- Added the PM boundary comment to #28 through `gh issue comment`, then corrected its timestamp through `gh api repos/zfifteen/handrail/issues/comments/4363016759 -X PATCH`.
- No build, unit test, or simulator validation was run because this PM pass changed product/readiness documentation and GitHub tracking only, not app code or visible iPhone/iPad UI behavior.
