import { readFile } from "node:fs/promises";
import { access, readdir } from "node:fs/promises";
import { join } from "node:path";
import { grokSessionsRoot } from "./grokPaths.js";

export type GrokTranscriptRole = "user" | "grok" | "tool";

export interface GrokTranscriptLine {
  role: GrokTranscriptRole;
  text: string;
}

export interface GrokTranscriptResult {
  sessionId: string;
  lines: string[];
  structured: GrokTranscriptLine[];
}

interface UpdatesLine {
  method?: string;
  params?: {
    sessionId?: string;
    update?: {
      sessionUpdate?: string;
      content?: { type?: string; text?: string };
      title?: string;
    };
  };
}

export function formatGrokTranscriptEntry(role: GrokTranscriptRole, text: string): string {
  const label = role === "user" ? "User" : role === "grok" ? "Grok" : "Tool";
  return `${label}:\n${text.trim()}\n\n`;
}

export function parseUpdatesJsonlText(raw: string): GrokTranscriptResult {
  const structured: GrokTranscriptLine[] = [];
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
      structured.push({ role: "tool", text: `[${update.title ?? "tool"}]` });
    }
  }

  flushUser();
  flushGrok();

  return {
    sessionId,
    lines: structured.map((entry) => formatGrokTranscriptEntry(entry.role, entry.text)),
    structured
  };
}

export async function parseUpdatesJsonl(updatesPath: string): Promise<GrokTranscriptResult> {
  return parseUpdatesJsonlText(await readFile(updatesPath, "utf8"));
}

export async function findUpdatesPath(sessionId: string): Promise<string | null> {
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
      // Keep scanning session groups.
    }
  }
  return null;
}