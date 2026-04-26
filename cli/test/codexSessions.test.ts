import test from "node:test";
import assert from "node:assert/strict";
import { formatCodexTranscriptEntry } from "../src/codexSessions.js";

test("formats imported Codex transcript entries for rich mobile rendering", () => {
  const entry = formatCodexTranscriptEntry("assistant", [
    "Yes, but only if SOUL.md has a different contract from AGENTS.md.",
    "A good split would be:",
    "",
    "```md",
    "# SOUL.md",
    "```",
    "",
    "- Preserve purpose.",
    "- Avoid drift."
  ].join("\n"));

  assert.equal(entry, [
    "Codex:",
    "Yes, but only if SOUL.md has a different contract from AGENTS.md.  ",
    "A good split would be:  ",
    "",
    "```md",
    "# SOUL.md",
    "```",
    "",
    "- Preserve purpose.  ",
    "- Avoid drift.  ",
    "",
    ""
  ].join("\n"));
});
