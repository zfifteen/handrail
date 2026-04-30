import { execFile } from "node:child_process";
import { access, open, readFile, readdir, stat } from "node:fs/promises";
import { basename, join } from "node:path";
import { homedir } from "node:os";
import { promisify } from "node:util";
import type { ChatRecord, ThinkingEntry } from "./types.js";
import { discoverDesktopProjects } from "./newChatOptions.js";

const MAX_CODEX_SESSIONS = 50;
const MAX_TRANSCRIPT_LINES = 40;
const MAX_TRANSCRIPT_CHARS = 12_000;
const MAX_TRANSCRIPT_ENTRY_CHARS = 2_500;
const MAX_THINKING_ENTRIES = 40;
const MAX_THINKING_CHARS = 12_000;
const MAX_THINKING_ENTRY_CHARS = 2_500;
const ROLLOUT_HEAD_BYTES = 64 * 1024;
const ROLLOUT_TAIL_BYTES = 2 * 1024 * 1024;
const STATUS_SCAN_CHUNK_BYTES = 64 * 1024;
const LINE_FEED = 10;
const execFileAsync = promisify(execFile);

interface CodexSessionMeta {
  id?: string;
  timestamp?: string;
  cwd?: string;
}

export interface CodexDesktopThread {
  id: string;
  rollout_path: string;
  cwd: string;
  title: string;
  first_user_message: string;
  created_at: number;
  updated_at: number;
}

export interface CodexDesktopThreadRow extends CodexDesktopThread {
  archived: number;
  source: string;
  first_user_message: string;
}

interface CodexSessionLine {
  timestamp?: string;
  type?: string;
  payload?: {
    type?: string;
    role?: string;
    thread_name?: string;
    text?: string;
    content?: Array<{ type?: string; text?: string }>;
  };
}

export async function listCodexChats(): Promise<ChatRecord[]> {
  const desktopThreads = await readDesktopThreads();
  const pinnedThreadIds = await readDesktopPinnedThreadIds();
  const automationTargetThreadIds = await readDesktopAutomationTargetThreadIds();
  const projectNames = new Map(
    (await discoverDesktopProjects())
      .filter((project) => project.path)
      .map((project) => [project.path!, project.name])
  );
  const records: ChatRecord[] = [];
  for (const thread of desktopThreads) {
    const record = await readCodexSession(thread, pinnedThreadIds, automationTargetThreadIds, projectNames);
    if (record) {
      records.push(record);
    }
    if (records.length >= MAX_CODEX_SESSIONS) {
      break;
    }
  }
  return records;
}

async function readDesktopThreads(): Promise<CodexDesktopThread[]> {
  const databasePath = join(homedir(), ".codex", "state_5.sqlite");
  try {
    await access(databasePath);
  } catch {
    return [];
  }
  const sql = [
    "SELECT id, rollout_path, cwd, title, created_at, updated_at, archived, source, first_user_message",
    "FROM threads",
    "ORDER BY updated_at DESC, id DESC"
  ].join(" ");
  const { stdout } = await execFileAsync("sqlite3", ["-json", databasePath, sql], { maxBuffer: 5_000_000 });
  return visibleDesktopThreads(JSON.parse(stdout || "[]") as CodexDesktopThreadRow[]);
}

export function visibleDesktopThreads(rows: CodexDesktopThreadRow[]): CodexDesktopThread[] {
  return rows
    .filter((row) =>
      row.archived === 0 &&
      row.source === "vscode" &&
      typeof row.first_user_message === "string" &&
      row.first_user_message.trim().length > 0
    )
    .sort((left, right) => right.updated_at - left.updated_at)
    .slice(0, MAX_CODEX_SESSIONS)
    .map(({ id, rollout_path, cwd, title, first_user_message, created_at, updated_at }) => ({
      id,
      rollout_path,
      cwd,
      title,
      first_user_message,
      created_at,
      updated_at
    }));
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

async function readDesktopAutomationTargetThreadIds(): Promise<Set<string>> {
  const automationRoot = join(process.env.CODEX_HOME ?? join(homedir(), ".codex"), "automations");
  try {
    await access(automationRoot);
  } catch {
    return new Set();
  }

  const entries = await readdir(automationRoot, { withFileTypes: true });
  const targets = new Set<string>();
  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue;
    }
    const targetId = parseAutomationTargetThreadId(
      await readFile(join(automationRoot, entry.name, "automation.toml"), "utf8")
    );
    if (targetId) {
      targets.add(targetId);
    }
  }
  return targets;
}

export function parseAutomationTargetThreadId(raw: string): string | null {
  const match = raw.match(/^target_thread_id = "([^"\n]+)"$/m);
  return match ? match[1] : null;
}

async function readCodexSession(
  thread: CodexDesktopThread,
  pinnedThreadIds: Map<string, number>,
  automationTargetThreadIds: Set<string>,
  projectNames: Map<string, string>
): Promise<ChatRecord | null> {
  const lines = await readRolloutLines(thread.rollout_path);
  const firstLine = lines[0];
  if (!firstLine) {
    return null;
  }

  const parsed = parseLine<{ type?: string; payload?: CodexSessionMeta }>(firstLine);
  if (parsed.type !== "session_meta" || !parsed.payload?.id || !parsed.payload.timestamp) {
    return null;
  }

  const repo = thread.cwd || parsed.payload.cwd || homedir();
  const status = await readCodexSessionStatus(thread.rollout_path);
  return {
    id: `codex:${parsed.payload.id}`,
    repo,
    title: humanCodexTitle(thread.title, extractTitle(lines.slice(1)), thread.first_user_message, repo),
    projectName: desktopProjectName(repo, projectNames),
    status,
    startedAt: unixSecondsToIso(thread.created_at) || parsed.payload.timestamp,
    updatedAt: unixSecondsToIso(thread.updated_at) || extractUpdatedAt(lines) || parsed.payload.timestamp,
    transcript: extractTranscript(lines.slice(1)),
    thinking: extractThinking(lines.slice(1)),
    isPinned: pinnedThreadIds.has(parsed.payload.id),
    pinnedOrder: pinnedThreadIds.get(parsed.payload.id),
    isAutomationTarget: automationTargetThreadIds.has(parsed.payload.id)
  };
}

export function humanCodexTitle(
  desktopTitle: string,
  rolloutTitle: string | null,
  firstUserMessage: string,
  repo: string
): string {
  for (const candidate of [desktopTitle, rolloutTitle ?? "", firstUserMessage]) {
    const title = compactTitle(candidate);
    if (title && !isRawCodexIdentifier(title)) {
      return title;
    }
  }
  return basename(repo);
}

export async function readRolloutLines(path: string): Promise<string[]> {
  const info = await stat(path);
  if (info.size <= ROLLOUT_HEAD_BYTES + ROLLOUT_TAIL_BYTES) {
    return (await readFile(path, "utf8")).split("\n").filter(Boolean);
  }

  const file = await open(path, "r");
  try {
    const headBuffer = Buffer.alloc(ROLLOUT_HEAD_BYTES);
    const tailBuffer = Buffer.alloc(ROLLOUT_TAIL_BYTES);
    const head = await file.read(headBuffer, 0, ROLLOUT_HEAD_BYTES, 0);
    const tailStart = Math.max(0, info.size - ROLLOUT_TAIL_BYTES);
    const tail = await file.read(tailBuffer, 0, ROLLOUT_TAIL_BYTES, tailStart);
    const headLines = headBuffer.subarray(0, head.bytesRead).toString("utf8").split("\n");
    const tailLines = tailBuffer.subarray(0, tail.bytesRead).toString("utf8").split("\n");
    return [
      ...headLines.slice(0, 1),
      ...tailLines.slice(1)
    ].filter(Boolean);
  } finally {
    await file.close();
  }
}

export function desktopProjectName(repo: string, projectNames: Map<string, string>): string {
  return projectNames.get(repo) ?? basename(repo);
}

function unixSecondsToIso(value: number): string | null {
  if (!Number.isFinite(value) || value <= 0) {
    return null;
  }
  return new Date(value * 1000).toISOString();
}

function extractUpdatedAt(lines: string[]): string | null {
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    const parsed = parseLine<CodexSessionLine>(lines[index]);
    if (parsed.timestamp) {
      return parsed.timestamp;
    }
  }
  return null;
}

function extractTitle(lines: string[]): string | null {
  for (const line of lines) {
    const parsed = parseLine<CodexSessionLine>(line);
    if (parsed.type === "event_msg" && parsed.payload?.type === "thread_name_updated") {
      return parsed.payload.thread_name?.trim() || null;
    }
  }
  return null;
}

function compactTitle(value: string): string | null {
  const compact = value.replace(/\s+/g, " ").trim();
  if (!compact) {
    return null;
  }
  return compact.length > 96 ? `${compact.slice(0, 93)}...` : compact;
}

function isRawCodexIdentifier(value: string): boolean {
  const candidate = value.replace(/^codex:/i, "");
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(candidate);
}

export async function readCodexSessionStatus(path: string): Promise<ChatRecord["status"]> {
  const info = await stat(path);
  const file = await open(path, "r");
  try {
    let position = info.size;
    let suffix = Buffer.alloc(0);

    while (position > 0) {
      const chunkSize = Math.min(STATUS_SCAN_CHUNK_BYTES, position);
      position -= chunkSize;

      const buffer = Buffer.alloc(chunkSize);
      const result = await file.read(buffer, 0, chunkSize, position);
      const combined = Buffer.concat([buffer.subarray(0, result.bytesRead), suffix]);
      let lineEnd = combined.length;

      for (let index = combined.length - 1; index >= 0; index -= 1) {
        if (combined[index] !== LINE_FEED) {
          continue;
        }

        const status = extractStatusFromLine(combined.subarray(index + 1, lineEnd).toString("utf8"));
        if (status) {
          return status;
        }
        lineEnd = index;
      }

      suffix = combined.subarray(0, lineEnd);
    }

    return extractStatusFromLine(suffix.toString("utf8")) ?? "idle";
  } finally {
    await file.close();
  }
}

export function extractStatus(lines: string[]): ChatRecord["status"] {
  for (let index = lines.length - 1; index >= 0; index -= 1) {
    const status = extractStatusFromLine(lines[index]);
    if (status) {
      return status;
    }
  }
  return "idle";
}

function extractStatusFromLine(line: string): ChatRecord["status"] | null {
  const parsed = parseLine<CodexSessionLine>(line);
  if (parsed.type !== "event_msg") {
    return null;
  }
  switch (parsed.payload?.type) {
    case "task_complete":
      return "completed";
    case "task_failed":
      return "failed";
    case "task_interrupted":
      return "stopped";
    case "task_started":
      return "running";
    default:
      return null;
  }
}

export function extractTranscript(lines: string[]): string[] {
  const entries: string[] = [];

  for (const line of lines) {
    const parsed = parseLine<CodexSessionLine>(line);
    const payload = parsed.payload;
    if (parsed.type !== "response_item" || payload?.type !== "message") {
      continue;
    }
    if (payload.role !== "user" && payload.role !== "assistant") {
      continue;
    }

    const text = messageText(payload);
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

export function extractThinking(lines: string[]): ThinkingEntry[] {
  const entries: ThinkingEntry[] = [];
  let round = 0;

  lines.forEach((line, index) => {
    const parsed = parseLine<CodexSessionLine>(line);
    const payload = parsed.payload;
    if (parsed.type === "response_item" && payload?.type === "message" && payload.role === "user") {
      const text = messageText(payload);
      if (text && !isSessionContext(text)) {
        round += 1;
      }
      return;
    }

    if (parsed.type !== "event_msg" || payload?.type !== "agent_reasoning") {
      return;
    }

    const text = payload.text?.trim();
    if (!text) {
      return;
    }

    const visibleText =
      text.length > MAX_THINKING_ENTRY_CHARS
        ? `${text.slice(0, MAX_THINKING_ENTRY_CHARS)}\n[truncated]`
        : text;
    entries.push({
      id: `thinking:${index}:${parsed.timestamp ?? "unknown"}`,
      round: Math.max(round, 1),
      text: markdownWithHardLineBreaks(visibleText),
      at: parsed.timestamp
    });
  });

  const thinking: ThinkingEntry[] = [];
  let usedChars = 0;
  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (usedChars + entry.text.length > MAX_THINKING_CHARS || thinking.length >= MAX_THINKING_ENTRIES) {
      break;
    }
    thinking.unshift(entry);
    usedChars += entry.text.length;
  }
  return thinking;
}

function messageText(payload: NonNullable<CodexSessionLine["payload"]>): string {
  return (payload.content ?? [])
    .filter((item) => item.type === "input_text" || item.type === "output_text")
    .map((item) => item.text?.trim() ?? "")
    .filter(Boolean)
    .join("\n\n");
}

function parseLine<T>(line: string): T {
  try {
    return JSON.parse(line) as T;
  } catch {
    return {} as T;
  }
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
