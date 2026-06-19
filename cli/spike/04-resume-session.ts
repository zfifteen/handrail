#!/usr/bin/env node
import { listGrokSessions } from "./lib/grokSessions.js";
import { AcpStdioClient } from "./lib/acpClient.js";

async function main(): Promise<void> {
  const requestedId = process.env.SPIKE_SESSION_ID?.trim();
  const sessions = await listGrokSessions(10);
  const picked = requestedId
    ? sessions.find((session) => session.sessionId === requestedId)
    : sessions.find((session) => !session.isActive) ?? sessions[0];

  if (!picked) {
    console.log(JSON.stringify({ spike: "04-resume-session", ok: false, error: "No session available to resume." }, null, 2));
    process.exit(1);
  }

  const client = new AcpStdioClient({ cwd: picked.cwd });
  let sawSessionUpdate = false;

  client.onNotification((method) => {
    if (method === "session/update") {
      sawSessionUpdate = true;
    }
  });

  try {
    await client.start();
    const init = await client.initialize();
    const loadResult = await client.loadSession(picked.sessionId, picked.cwd);

    const promptResult = await client.prompt(
      picked.sessionId,
      "Reply with exactly: handrail-resume-ok"
    );

    const stopReason = (promptResult as { stopReason?: string }).stopReason ?? null;
    const payload = {
      spike: "04-resume-session",
      ok: stopReason === "end_turn" || stopReason === "max_tokens",
      sessionId: picked.sessionId,
      cwd: picked.cwd,
      title: picked.title,
      loadSessionKeys: Object.keys(loadResult),
      agentSupportsLoadSession: Boolean((init.agentCapabilities as { loadSession?: boolean } | undefined)?.loadSession),
      sawSessionUpdate,
      stopReason
    };

    console.log(JSON.stringify(payload, null, 2));
    process.exit(payload.ok ? 0 : 1);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.log(JSON.stringify({
      spike: "04-resume-session",
      ok: false,
      sessionId: picked.sessionId,
      cwd: picked.cwd,
      error: message
    }, null, 2));
    process.exit(1);
  } finally {
    await client.close();
  }
}

void main();