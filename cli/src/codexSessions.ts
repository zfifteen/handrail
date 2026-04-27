import { readdir, readFile } from "node:fs/promises";
import { basename, join } from "node:path";
import { homedir } from "node:os";
import type { SessionRecord } from "./types.js";

const MAX_CODEX_SESSIONS = 50;
const MAX_TRANSCRIPT_LINES = 40;
const MAX_TRANSCRIPT_CHARS = 12_000;
const MAX_TRANSCRIPT_ENTRY_CHARS = 2_500;
const SESSION_ID_PATTERN = /([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jsonl$/;

interface CodexSessionMeta {
  id?: string;
  timestamp?: string;
  cwd?: string;
}

interface CodexSessionIndexEntry {
  id: string;
  thread_name?: string;
  updated_at?: string;
}

interface CodexSessionLine {
  timestamp?: string;
  type?: string;
  payload?: {
    type?: string;
    role?: string;
    thread_name?: string;
    content?: Array<{ type?: string; text?: string }>;
  };
}

export async function listCodexSessions(): Promise<SessionRecord[]> {
  const index = await readSessionIndex();
  const pinnedThreadIds = await readDesktopPinnedThreadIds();
  const paths = await listLiveSessionFiles();
  const records: SessionRecord[] = [];
  for (const entry of index.sort((left, right) => timestampValue(right.updated_at) - timestampValue(left.updated_at))) {
    const path = paths.get(entry.id);
    if (!path) {
      continue;
    }
    const record = await readCodexSession(path, entry, pinnedThreadIds);
    if (record) {
      records.push(record);
    }
    if (records.length >= MAX_CODEX_SESSIONS) {
      break;
    }
  }
  return records;
}

async function readSessionIndex(): Promise<CodexSessionIndexEntry[]> {
  const path = join(homedir(), ".codex", "session_index.jsonl");
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch {
    return [];
  }

  const entries = new Map<string, CodexSessionIndexEntry>();
  for (const line of raw.split("\n")) {
    if (!line.trim()) {
      continue;
    }
    const entry = JSON.parse(line) as CodexSessionIndexEntry;
    if (entry.id) {
      entries.set(entry.id, entry);
    }
  }
  return Array.from(entries.values());
}

async function readDesktopPinnedThreadIds(): Promise<Map<string, number>> {
  const path = join(homedir(), ".codex", ".codex-global-state.json");
  try {
    return parseDesktopPinnedThreadIds(await readFile(path, "utf8"));
  } catch {
    return new Map();
  }
}

export function parseDesktopPinnedThreadIds(raw: string): Map<string, number> {
  const parsed = JSON.parse(raw) as { "pinned-thread-ids"?: unknown };
  const ids = parsed["pinned-thread-ids"];
  if (!Array.isArray(ids)) {
    return new Map();
  }
  const pinned = new Map<string, number>();
  ids.forEach((id, index) => {
    if (typeof id === "string" && id.trim().length > 0) {
      pinned.set(id, index);
    }
  });
  return pinned;
}

async function listLiveSessionFiles(): Promise<Map<string, string>> {
  const root = join(homedir(), ".codex", "sessions");
  const paths = new Map<string, string>();
  await collectSessionFiles(root, paths);
  return paths;
}

async function collectSessionFiles(dir: string, paths: Map<string, string>): Promise<void> {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return;
  }

  for (const entry of entries) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) {
      await collectSessionFiles(path, paths);
      continue;
    }
    const match = entry.name.match(SESSION_ID_PATTERN);
    if (match) {
      paths.set(match[1], path);
    }
  }
}

async function readCodexSession(path: string, indexEntry: CodexSessionIndexEntry, pinnedThreadIds: Map<string, number>): Promise<SessionRecord | null> {
  const raw = await readFile(path, "utf8");
  const lines = raw.split("\n").filter(Boolean);
  const firstLine = lines[0];
  if (!firstLine) {
    return null;
  }

  const parsed = JSON.parse(firstLine) as { type?: string; payload?: CodexSessionMeta };
  if (parsed.type !== "session_meta" || !parsed.payload?.id || !parsed.payload.timestamp) {
    return null;
  }

  const repo = parsed.payload.cwd || homedir();
  return {
    id: `codex:${parsed.payload.id}`,
    repo,
    title: indexEntry.thread_name?.trim() || extractTitle(lines.slice(1)) || basename(repo),
    status: "idle",
    startedAt: parsed.payload.timestamp,
    updatedAt: indexEntry.updated_at || extractUpdatedAt(lines) || parsed.payload.timestamp,
    source: "codex",
    transcript: extractTranscript(lines.slice(1)),
    isPinned: pinnedThreadIds.has(parsed.payload.id),
    pinnedOrder: pinnedThreadIds.get(parsed.payload.id)
  };
}

function extractUpdatedAt(lines: string[]): string | null {
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    const parsed = JSON.parse(lines[index]) as CodexSessionLine;
    if (parsed.timestamp) {
      return parsed.timestamp;
    }
  }
  return null;
}

function timestampValue(value?: string): number {
  return value ? new Date(value).getTime() : 0;
}

function extractTitle(lines: string[]): string | null {
  for (const line of lines) {
    const parsed = JSON.parse(line) as CodexSessionLine;
    if (parsed.type === "event_msg" && parsed.payload?.type === "thread_name_updated") {
      return parsed.payload.thread_name?.trim() || null;
    }
  }
  return null;
}

function extractTranscript(lines: string[]): string[] {
  const entries: string[] = [];

  for (const line of lines) {
    const parsed = JSON.parse(line) as CodexSessionLine;
    const payload = parsed.payload;
    if (parsed.type !== "response_item" || payload?.type !== "message") {
      continue;
    }
    if (payload.role !== "user" && payload.role !== "assistant") {
      continue;
    }

    const text = (payload.content ?? [])
      .filter((item) => item.type === "input_text" || item.type === "output_text")
      .map((item) => item.text?.trim() ?? "")
      .filter(Boolean)
      .join("\n\n");
    if (!text || isSessionContext(text)) {
      continue;
    }

    const visibleText =
      text.length > MAX_TRANSCRIPT_ENTRY_CHARS
        ? `${text.slice(0, MAX_TRANSCRIPT_ENTRY_CHARS)}\n[truncated]`
        : text;
    entries.push(formatCodexTranscriptEntry(payload.role, visibleText));
  }

  const transcript: string[] = [];
  let usedChars = 0;
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (usedChars + entry.length > MAX_TRANSCRIPT_CHARS || transcript.length >= MAX_TRANSCRIPT_LINES) {
      break;
    }
    transcript.unshift(entry);
    usedChars += entry.length;
  }

  return transcript;
}

function isSessionContext(text: string): boolean {
  return text.startsWith("# AGENTS.md instructions") || text.startsWith("<environment_context>");
}

export function formatCodexTranscriptEntry(role: string, text: string): string {
  const label = role === "user" ? "User" : "Codex";
  return `${label}:\n${markdownWithHardLineBreaks(text)}\n\n`;
}

function markdownWithHardLineBreaks(text: string): string {
  const lines = text
    .replace(/\r\n/g, "\n")
    .trim()
    .split("\n");
  let inCodeBlock = false;

  return lines.map((line) => {
    if (line.trimStart().startsWith("```")) {
      inCodeBlock = !inCodeBlock;
      return line;
    }
    if (inCodeBlock || line.trim().length === 0 || line.endsWith("  ")) {
      return line;
    }
    return `${line}  `;
  }).join("\n");
}
