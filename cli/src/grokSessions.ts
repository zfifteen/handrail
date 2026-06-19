import { access, readFile, readdir } from "node:fs/promises";
import { basename, join } from "node:path";
import { grokActiveSessionsPath, grokSessionsRoot } from "./grokPaths.js";
import { findUpdatesPath, parseUpdatesJsonl } from "./grokTranscript.js";
import type { ChatRecord } from "./types.js";

const MAX_GROK_SESSIONS = 50;

interface SummaryJson {
  info?: { id?: string; cwd?: string };
  session_summary?: string;
  generated_title?: string;
  created_at?: string;
  updated_at?: string;
  current_model_id?: string;
}

interface ActiveSessionRow {
  session_id: string;
  pid: number;
  cwd: string;
  opened_at: string;
}

export function grokChatId(sessionId: string): string {
  return `grok:${sessionId}`;
}

export function grokSessionId(chatId: string): string {
  if (!chatId.startsWith("grok:")) {
    throw new Error(`No Grok chat with id ${chatId}.`);
  }
  return chatId.slice("grok:".length);
}

export async function listGrokChats(): Promise<ChatRecord[]> {
  const root = grokSessionsRoot();
  try {
    await access(root);
  } catch {
    return [];
  }

  const activeIds = await readActiveSessionIds();
  const records: ChatRecord[] = [];

  for await (const summaryPath of walkSummaryFiles(root)) {
    const parsed = JSON.parse(await readFile(summaryPath, "utf8")) as SummaryJson;
    const sessionId = parsed.info?.id;
    if (!sessionId) {
      continue;
    }

    const repo = parsed.info?.cwd ?? "";
    records.push({
      id: grokChatId(sessionId),
      repo,
      title: humanGrokTitle(parsed.generated_title || parsed.session_summary, sessionId, repo),
      projectName: repo ? basename(repo) : undefined,
      status: activeIds.has(sessionId) ? "running" : "idle",
      startedAt: parsed.created_at ?? new Date(0).toISOString(),
      updatedAt: parsed.updated_at ?? undefined,
      acceptsInput: false
    });
  }

  records.sort((left, right) => new Date(right.updatedAt ?? right.startedAt).getTime() - new Date(left.updatedAt ?? left.startedAt).getTime());
  return records.slice(0, MAX_GROK_SESSIONS);
}

export async function readGrokChatDetail(chatId: string): Promise<ChatRecord | null> {
  const sessionId = grokSessionId(chatId);
  const chats = await listGrokChats();
  const summary = chats.find((chat) => chat.id === chatId);
  if (!summary) {
    return null;
  }

  const updatesPath = await findUpdatesPath(sessionId);
  if (!updatesPath) {
    return summary;
  }

  const transcript = await parseUpdatesJsonl(updatesPath);
  return {
    ...summary,
    transcript: transcript.lines
  };
}

export function humanGrokTitle(title: string | undefined, sessionId: string, repo: string): string {
  const trimmed = title?.trim() ?? "";
  if (!trimmed || trimmed === sessionId || /^grok:[0-9a-f-]+$/i.test(trimmed)) {
    return repo ? basename(repo) : "Grok chat";
  }
  return trimmed;
}

async function readActiveSessionIds(): Promise<Set<string>> {
  try {
    const rows = JSON.parse(await readFile(grokActiveSessionsPath(), "utf8")) as ActiveSessionRow[];
    return new Set(rows.map((row) => row.session_id));
  } catch {
    return new Set();
  }
}

async function* walkSummaryFiles(root: string): AsyncGenerator<string> {
  const cwdGroups = await readdir(root, { withFileTypes: true });
  for (const group of cwdGroups) {
    if (!group.isDirectory()) {
      continue;
    }
    const groupPath = join(root, group.name);
    const sessionDirs = await readdir(groupPath, { withFileTypes: true });
    for (const sessionDir of sessionDirs) {
      if (!sessionDir.isDirectory()) {
        continue;
      }
      const summaryPath = join(groupPath, sessionDir.name, "summary.json");
      try {
        await access(summaryPath);
        yield summaryPath;
      } catch {
        // Skip unreadable session directories.
      }
    }
  }
}