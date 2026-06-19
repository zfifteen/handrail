import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { grokSessionsRoot } from "./grokPaths.js";

export interface HandrailTranscriptLine {
  role: "user" | "grok" | "tool";
  text: string;
}

export interface HandrailTranscriptResult {
  sessionId: string;
  lines: string[];
  structured: HandrailTranscriptLine[];
}

interface UpdatesLine {
  method?: string;
  params?: {
    sessionId?: string;
    update?: {
      sessionUpdate?: string;
      content?: { type?: string; text?: string };
      title?: string;
      status?: string;
    };
  };
}

/**
 * Parse a Grok updates.jsonl file into Handrail-shaped transcript lines.
 * Output format mirrors codexSessions.formatCodexTranscriptEntry ("User:" / "Grok:" blocks).
 */
export async function parseUpdatesJsonl(updatesPath: string): Promise<HandrailTranscriptResult> {
  const raw = await readFile(updatesPath, "utf8");
  const structured: HandrailTranscriptLine[] = [];
  let sessionId = "";
  let userBuffer = "";
  let grokBuffer = "";

  const flushUser = (): void => {
    const text = userBuffer.trim();
    if (text.length > 0) {
      structured.push({ role: "user", text });
    }
    userBuffer = "";
  };

  const flushGrok = (): void => {
    const text = grokBuffer.trim();
    if (text.length > 0) {
      structured.push({ role: "grok", text });
    }
    grokBuffer = "";
  };

  for (const line of raw.split("\n")) {
    if (!line.trim()) {
      continue;
    }
    const event = JSON.parse(line) as UpdatesLine;
    if (event.method !== "session/update") {
      continue;
    }

    sessionId = event.params?.sessionId ?? sessionId;
    const update = event.params?.update;
    const kind = update?.sessionUpdate;
    if (!kind) {
      continue;
    }

    if (kind === "user_message_chunk") {
      flushGrok();
      userBuffer += update.content?.text ?? "";
      continue;
    }

    if (kind === "agent_message_chunk") {
      flushUser();
      grokBuffer += update.content?.text ?? "";
      continue;
    }

    if (kind === "tool_call") {
      flushUser();
      flushGrok();
      const title = update.title ?? "tool";
      structured.push({ role: "tool", text: `[${title}]` });
    }
  }

  flushUser();
  flushGrok();

  const lines = structured.map((entry) => formatHandrailTranscriptEntry(entry.role, entry.text));
  return { sessionId, lines, structured };
}

/** Locate updates.jsonl for a session id under ~/.grok/sessions. */
export async function findUpdatesPath(sessionId: string): Promise<string | null> {
  const { readdir, access } = await import("node:fs/promises");
  const root = grokSessionsRoot();

  const cwdGroups = await readdir(root, { withFileTypes: true });
  for (const group of cwdGroups) {
    if (!group.isDirectory()) {
      continue;
    }
    const candidate = join(root, group.name, sessionId, "updates.jsonl");
    try {
      await access(candidate);
      return candidate;
    } catch {
      // Keep scanning.
    }
  }
  return null;
}

export function formatHandrailTranscriptEntry(role: HandrailTranscriptLine["role"], text: string): string {
  const label = role === "user" ? "User" : role === "grok" ? "Grok" : "Tool";
  return `${label}:\n${text.trim()}\n\n`;
}