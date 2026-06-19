#!/usr/bin/env node
import { listGrokSessions } from "./lib/grokSessions.js";

const limit = Number(process.env.SPIKE_LIMIT ?? "5");

const sessions = await listGrokSessions(limit);
const payload = {
  spike: "01-list-sessions",
  ok: sessions.length > 0,
  count: sessions.length,
  sessions: sessions.map((session) => ({
    id: `grok:${session.sessionId}`,
    title: session.title,
    repo: session.cwd,
    status: session.isActive ? "running" : "idle",
    updatedAt: session.updatedAt,
    modelId: session.modelId
  }))
};

console.log(JSON.stringify(payload, null, 2));
process.exit(payload.ok ? 0 : 1);