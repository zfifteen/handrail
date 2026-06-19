#!/usr/bin/env node
import { findGrokSession, listGrokSessions } from "./lib/grokSessions.js";
import { findUpdatesPath, parseUpdatesJsonl } from "./lib/transcript.js";

const sessionId = process.env.SPIKE_SESSION_ID?.trim();
const picked = sessionId
  ? await findGrokSession(sessionId)
  : (await listGrokSessions(1))[0] ?? null;

if (!picked) {
  console.log(JSON.stringify({ spike: "02-parse-transcript", ok: false, error: "No Grok session found on disk." }, null, 2));
  process.exit(1);
}

const updatesPath = await findUpdatesPath(picked.sessionId);
if (!updatesPath) {
  console.log(JSON.stringify({
    spike: "02-parse-transcript",
    ok: false,
    sessionId: picked.sessionId,
    error: "updates.jsonl not found for session."
  }, null, 2));
  process.exit(1);
}

const transcript = await parseUpdatesJsonl(updatesPath);
const payload = {
  spike: "02-parse-transcript",
  ok: transcript.lines.length > 0,
  sessionId: picked.sessionId,
  updatesPath,
  lineCount: transcript.lines.length,
  sampleLines: transcript.lines.slice(0, 4),
  structuredSample: transcript.structured.slice(0, 6)
};

console.log(JSON.stringify(payload, null, 2));
process.exit(payload.ok ? 0 : 1);