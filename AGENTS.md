# Handrail Local Agent Instructions

## Product Invariant Gate

Every change must preserve Handrail as a free, local-first iOS remote control for Codex Desktop chats on the user's Mac.

Stop and record the product decision needed if a change implies any of these directions:

- Cloud relay, hosted execution, or cloud chat storage.
- Account, login, sync identity, or payment state.
- Generic terminal or SSH behavior.
- Multi-agent control plane behavior.
- Support for Claude, Gemini, OpenCode, or other non-Codex agents.
- Direct file editing from iOS instead of supervising Codex Desktop.

## Durable Evidence

Product claims require evidence. App Store metadata, screenshots, privacy copy, protocol behavior, simulator validation, milestones, and releases must all match the local-first Codex Desktop-only promise.

For Handrail iPhone or iPad UI behavior, simulator validation is required before reporting completion. Build success or unit tests alone are not enough for visible UI, navigation, decoded screen data, gestures, context menus, sheets, tabs, lists, or empty states.

For physical iPhone or iPad app updates, use `tools/release/update_ios_release.py`. The release update path must bump the iOS patch version, increment the build number, stamp `HANDRAIL_LAST_UPDATED`, commit only the release metadata, push the `ios-vX.Y.Z` tag, create the GitHub release, build Release for physical iOS, and install that exact build. Do not use ad hoc `xcodebuild` for physical app updates. Debug, simulator, and CI builds must remain non-mutating and must not create GitHub releases.

## Working Style

Prefer one narrow deterministic path. Do not add fallback workflows, broad frameworks, speculative future-proofing, or extra modes unless the exact task requires them. Preserve unrelated user changes.
