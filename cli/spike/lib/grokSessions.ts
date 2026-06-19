import { access, readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { grokActiveSessionsPath, grokSessionsRoot } from "./grokPaths.js";

export interface GrokSessionSummary {
  sessionId: string;
  cwd: string;
  title: string;
  createdAt: string;
  updatedAt: string;
  modelId: string;
  isActive: boolean;
}

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

/** List Grok sessions by scanning ~/.grok/sessions for summary.json files. */
export async function listGrokSessions(limit = 20): Promise<GrokSessionSummary[]> {
  const root = grokSessionsRoot();
  try {
    await access(root);
  } catch {
    return [];
  }

  const activeIds = await readActiveSessionIds();
  const summaries: GrokSessionSummary[] = [];

  for await (const summaryPath of walkSummaryFiles(root)) {
    const raw = await readFile(summaryPath, "utf8");
    const parsed = JSON.parse(raw) as SummaryJson;
    const sessionId = parsed.info?.id;
    if (!sessionId) {
      continue;
    }

    summaries.push({
      sessionId,
      cwd: parsed.info?.cwd ?? "",
      title: parsed.generated_title || parsed.session_summary || "Untitled session",
      createdAt: parsed.created_at ?? "",
      updatedAt: parsed.updated_at ?? "",
      modelId: parsed.current_model_id ?? "",
      isActive: activeIds.has(sessionId)
    });
  }

  summaries.sort((left, right) => right.updatedAt.localeCompare(left.updatedAt));
  return summaries.slice(0, limit);
}

/** Find one session on disk by id (used by resume spike). */
export async function findGrokSession(sessionId: string): Promise<GrokSessionSummary | null> {
  const sessions = await listGrokSessions(500);
  return sessions.find((session) => session.sessionId === sessionId) ?? null;
}

async function readActiveSessionIds(): Promise<Set<string>> {
  try {
    const raw = await readFile(grokActiveSessionsPath(), "utf8");
    const rows = JSON.parse(raw) as ActiveSessionRow[];
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
        // Skip groups without a readable summary.
      }
    }
  }
}