# Handrail Chat Codex Desktop Clone Contract

Handrail chat must clone the Codex Desktop chat interaction model on iPhone as closely as the smaller screen permits.

This is not a request for a nicer Handrail-branded chat. This is not a request for a generic mobile chat redesign. This is a product requirement: the chat screen is a mobile controller for Codex Desktop chats, so Codex Desktop is the visual and behavioral source of truth.

## Source Of Truth

The implementation target is Codex Desktop chat.

The iPhone version must preserve the same hierarchy:

- Session title and context identify the chat.
- The transcript is the primary surface.
- Codex output and user input appear as conversation turns, not dashboard cards.
- Thinking, files, diffs, approvals, and running status appear as compact Codex-style conversation artifacts.
- The composer is the primary bottom surface whenever the chat can receive input or continue.
- Session status is contextual and compact.

Any deviation from Codex Desktop must be caused by an iPhone constraint and documented in the implementation notes.

## Explicit Failures

An implementation fails this contract if the normal iPhone chat detail screen contains any of the following:

- User-visible `Round 1`, `Round 2`, or similar parser/internal turn labels.
- A persistent bottom tab bar inside chat detail.
- Giant full-width message cards that make the transcript read like a debug report.
- Purple user slabs as the dominant visual language.
- Dashboard-style status panels such as a large `Codex is working` block occupying the composer/status region.
- A header whose controls or blur treatment consume transcript space without matching Codex Desktop behavior.
- A color palette driven by Handrail accent styling instead of Codex Desktop neutrals.
- File, diff, thinking, or approval blocks rendered as unrelated dashboard cards instead of inline chat artifacts.

These are rejection criteria, not polish notes.

## Current Violation Evidence

The current simulator captures from May 8, 2026 show the contract violation:

- `test-artifacts/chat-ui-screenshots-20260508/02-chat-current-session.png`
- `test-artifacts/chat-ui-screenshots-20260508/03-chat-bottom-status.png`
- `test-artifacts/chat-ui-screenshots-20260508/05-chat-followup-composer.png`
- `test-artifacts/chat-ui-screenshots-20260508/06-chat-composer-focused.png`

Observed failures:

- The screen exposes `Round 1` and `Round 2`.
- The bottom tab bar remains visible in chat detail and competes with the latest message, status, and composer.
- The transcript uses oversized cards and oversized text.
- User turns are large purple blocks.
- Running state appears as a large green status slab.
- The composer is visually subordinate to navigation chrome.

## Acceptance Requirement

A chat redesign is acceptable only when a side-by-side review against Codex Desktop shows the same interaction model:

- Comparable transcript density.
- Comparable message hierarchy.
- Comparable neutral color treatment.
- Comparable bottom composer priority.
- Comparable inline treatment for status, thinking, files, diffs, and approvals.
- No dashboard/tab chrome inside the focused chat detail screen.

Simulator validation is mandatory before reporting the redesign complete. Screenshots must include:

- A running chat.
- A completed chat with follow-up composer.
- A focused composer.
- A chat containing file or diff artifacts.
- A chat requiring approval, if a live approval fixture is available.

If these screenshots still show any explicit failure listed above, the work is not complete.
