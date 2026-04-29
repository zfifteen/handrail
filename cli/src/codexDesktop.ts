import { execFile } from "node:child_process";
import { readdir } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const DESKTOP_SOURCE = "vscode";

export interface DesktopThreadPromotion {
  databasePath: string;
  sql: string;
}

export interface DesktopThreadMetadata {
  cwd: string;
  model?: string;
  reasoningEffort?: string;
  sandboxPolicy?: string;
  approvalMode?: string;
}

interface DesktopThreadState {
  source: string;
  updated_at_ms: number;
  rollout_path: string;
}

export async function promoteCodexThreadToDesktop(threadId: string, title: string, firstUserMessage: string, metadata: DesktopThreadMetadata): Promise<void> {
  const rolloutPath = await waitForCodexRolloutPath(threadId);
  const promotion = desktopThreadPromotion(threadId, title, firstUserMessage, Date.now(), {
    ...metadata,
    rolloutPath
  });
  const { stdout } = await execFileAsync("sqlite3", [
    promotion.databasePath,
    promotion.sql
  ]);
  if (stdout.trim().split(/\r?\n/).at(-1) !== "1") {
    throw new Error(`Codex Desktop did not record thread ${threadId}; new chat could not be made Desktop-visible.`);
  }
}

export async function waitForCodexDesktopThreadSettled(threadId: string): Promise<void> {
  const databasePath = join(homedir(), ".codex", "state_5.sqlite");
  let lastSnapshot = "";
  let stableSince = 0;
  for (let attempt = 0; attempt < 80; attempt += 1) {
    const state = await readDesktopThreadState(databasePath, threadId);
    if (state) {
      const snapshot = `${state.source}|${state.updated_at_ms}|${state.rollout_path}`;
      if (snapshot === lastSnapshot) {
        stableSince += 250;
        if (stableSince >= 1_500) {
          return;
        }
      } else {
        lastSnapshot = snapshot;
        stableSince = 0;
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`Codex Desktop thread ${threadId} did not settle after Codex finished writing it.`);
}

export function desktopThreadPromotion(
  threadId: string,
  title: string,
  firstUserMessage: string,
  nowMs: number,
  metadata: DesktopThreadMetadata & { rolloutPath?: string } = { cwd: process.cwd() }
): DesktopThreadPromotion {
  const nowSeconds = Math.floor(nowMs / 1000);
  const source = sqliteString(DESKTOP_SOURCE);
  const quotedTitle = sqliteString(title);
  const quotedMessage = sqliteString(firstUserMessage);
  const quotedThreadId = sqliteString(threadId);
  const rolloutPath = sqliteString(metadata.rolloutPath ?? "");
  const cwd = sqliteString(metadata.cwd);
  const sandboxPolicy = sqliteString(metadata.sandboxPolicy ?? "");
  const approvalMode = sqliteString(metadata.approvalMode ?? "");
  const model = sqliteString(metadata.model ?? "");
  const reasoningEffort = sqliteString(metadata.reasoningEffort ?? "");
  return {
    databasePath: join(homedir(), ".codex", "state_5.sqlite"),
    sql: [
      "PRAGMA busy_timeout = 15000;",
      "INSERT INTO threads",
      "(id, rollout_path, created_at, updated_at, source, model_provider, cwd, title, sandbox_policy, approval_mode, has_user_event, first_user_message, model, reasoning_effort, created_at_ms, updated_at_ms)",
      "VALUES",
      `(${quotedThreadId}, ${rolloutPath}, ${nowSeconds}, ${nowSeconds}, 'exec', 'openai', ${cwd}, ${quotedTitle}, ${sandboxPolicy}, ${approvalMode}, 1, ${quotedMessage}, ${model}, ${reasoningEffort}, ${nowMs}, ${nowMs})`,
      "ON CONFLICT(id) DO NOTHING;",
      "UPDATE threads SET",
      `source = ${source},`,
      `title = CASE WHEN title = '' OR source = 'exec' THEN ${quotedTitle} ELSE title END,`,
      `first_user_message = CASE WHEN first_user_message = '' THEN ${quotedMessage} ELSE first_user_message END,`,
      "has_user_event = 1,",
      `updated_at = CASE WHEN updated_at < ${nowSeconds} THEN ${nowSeconds} ELSE updated_at END,`,
      `updated_at_ms = CASE WHEN updated_at_ms < ${nowMs} THEN ${nowMs} ELSE updated_at_ms END`,
      `WHERE id = ${quotedThreadId};`,
      "SELECT COUNT(*) FROM threads",
      `WHERE id = ${quotedThreadId}`,
      `AND source = ${source}`,
      "AND archived = 0",
      "AND first_user_message <> '';"
    ].join(" ")
  };
}

function sqliteString(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

async function readDesktopThreadState(databasePath: string, threadId: string): Promise<DesktopThreadState | null> {
  const { stdout } = await execFileAsync("sqlite3", [
    "-json",
    databasePath,
    [
      "PRAGMA busy_timeout = 15000;",
      "SELECT source, updated_at_ms, rollout_path FROM threads",
      `WHERE id = ${sqliteString(threadId)}`,
      "LIMIT 1;"
    ].join(" ")
  ]);
  const json = stdout.trim().split(/\r?\n/).at(-1) ?? "[]";
  const rows = JSON.parse(json) as DesktopThreadState[];
  return rows[0] ?? null;
}

async function waitForCodexRolloutPath(threadId: string): Promise<string> {
  for (let attempt = 0; attempt < 150; attempt += 1) {
    const path = await findCodexRolloutPath(threadId);
    if (path) {
      return path;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`Codex rollout file for thread ${threadId} was not found; new chat could not be made Desktop-visible.`);
}

async function findCodexRolloutPath(threadId: string): Promise<string | null> {
  const root = join(homedir(), ".codex", "sessions");
  const suffix = `${threadId}.jsonl`;
  return await findFile(root, suffix);
}

async function findFile(dir: string, suffix: string): Promise<string | null> {
  let entries;
  try {
    entries = await readdir(dir, { withFileTypes: true });
  } catch {
    return null;
  }
  for (const entry of entries) {
    const path = join(dir, entry.name);
    if (entry.isFile() && entry.name.endsWith(suffix)) {
      return path;
    }
    if (entry.isDirectory()) {
      const found = await findFile(path, suffix);
      if (found) {
        return found;
      }
    }
  }
  return null;
}
