import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { grokChatId, grokSessionId, humanGrokTitle } from "../src/grokSessions.js";
import { formatGrokTranscriptEntry, parseUpdatesJsonlText } from "../src/grokTranscript.js";

const fixtureDir = join(fileURLToPath(new URL("../../test/fixtures/grok", import.meta.url)));

test("maps Grok session ids to Handrail chat ids", () => {
  const sessionId = "019edfaa-8d31-7e72-b9b6-74a85305a1fb";
  assert.equal(grokChatId(sessionId), `grok:${sessionId}`);
  assert.equal(grokSessionId(`grok:${sessionId}`), sessionId);
});

test("rejects non-Grok chat ids when extracting session ids", () => {
  assert.throws(
    () => grokSessionId("codex:thread-1"),
    /No Grok chat with id codex:thread-1/
  );
});

test("humanizes Grok titles without echoing raw session ids", () => {
  const sessionId = "019edfaa-8d31-7e72-b9b6-74a85305a1fb";
  assert.equal(humanGrokTitle(sessionId, sessionId, "/Users/me/handrail"), "handrail");
  assert.equal(humanGrokTitle("Phase 1 adapter swap", sessionId, "/Users/me/handrail"), "Phase 1 adapter swap");
  assert.equal(humanGrokTitle(undefined, sessionId, ""), "Grok chat");
});

test("parses Grok updates.jsonl into Handrail transcript blocks", async () => {
  const raw = await readFile(join(fixtureDir, "sample-updates.jsonl"), "utf8");
  const transcript = parseUpdatesJsonlText(raw);

  assert.equal(transcript.sessionId, "019edfaa-8d31-7e72-b9b6-74a85305a1fb");
  assert.deepEqual(transcript.structured, [
    { role: "user", text: "List Grok sessions" },
    { role: "grok", text: "Here are your Grok sessions." },
    { role: "tool", text: "[Shell]" }
  ]);
  assert.deepEqual(transcript.lines, [
    formatGrokTranscriptEntry("user", "List Grok sessions"),
    formatGrokTranscriptEntry("grok", "Here are your Grok sessions."),
    formatGrokTranscriptEntry("tool", "[Shell]")
  ]);
});