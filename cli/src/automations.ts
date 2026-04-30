import { access, readFile, readdir } from "node:fs/promises";
import { basename, join } from "node:path";
import { homedir } from "node:os";
import type { AutomationRecord, AutomationStatus } from "./types.js";

export async function listDesktopAutomations(): Promise<AutomationRecord[]> {
  const automationRoot = join(process.env.CODEX_HOME ?? join(homedir(), ".codex"), "automations");
  try {
    await access(automationRoot);
  } catch {
    return [];
  }

  const targetThreads = await readAutomationTargetThreads();
  const entries = await readdir(automationRoot, { withFileTypes: true });
  const records: AutomationRecord[] = [];
  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue;
    }
    const record = parseAutomationToml(
      await readFile(join(automationRoot, entry.name, "automation.toml"), "utf8"),
      targetThreads
    );
    if (record) {
      records.push(record);
    }
  }
  records.sort((left, right) => {
    if (left.status === "ACTIVE" && right.status === "ACTIVE" && left.kind !== right.kind) {
      return left.kind === "cron" ? -1 : 1;
    }
    return 0;
  });
  return records;
}

export function parseAutomationToml(
  raw: string,
  targetThreads: Map<string, AutomationTargetThread> = new Map()
): AutomationRecord | null {
  const id = readString(raw, "id");
  const name = readString(raw, "name");
  const kind = readString(raw, "kind");
  const status = readString(raw, "status");
  const rrule = readString(raw, "rrule");
  if (!id || !name || !kind || !status || !rrule || !isAutomationStatus(status)) {
    return null;
  }

  const cwds = readStringArray(raw, "cwds");
  const targetThreadId = readString(raw, "target_thread_id");
  const targetThread = targetThreadId ? targetThreads.get(targetThreadId) : undefined;
  const projectPath = cwds[0] ?? targetThread?.cwd ?? null;
  return {
    id,
    name,
    kind,
    status,
    scheduleText: scheduleText(status, rrule),
    contextText: contextText(kind, cwds[0] ?? null, targetThreadId, targetThread?.title),
    projectName: projectPath ? basename(projectPath) : undefined,
    targetThreadId: targetThreadId ?? undefined
  };
}

interface AutomationTargetThread {
  cwd: string;
  title: string;
}

async function readAutomationTargetThreads(): Promise<Map<string, AutomationTargetThread>> {
  const databasePath = join(homedir(), ".codex", "state_5.sqlite");
  try {
    await access(databasePath);
  } catch {
    return new Map();
  }

  const { execFile } = await import("node:child_process");
  const { promisify } = await import("node:util");
  const execFileAsync = promisify(execFile);
  const sql = "SELECT id, cwd, title FROM threads";
  const { stdout } = await execFileAsync("sqlite3", ["-json", databasePath, sql], { maxBuffer: 5_000_000 });
  const rows = JSON.parse(stdout || "[]") as Array<{ id?: string; cwd?: string; title?: string }>;
  const threads = new Map<string, AutomationTargetThread>();
  for (const row of rows) {
    if (row.id && row.cwd && row.title) {
      threads.set(row.id, { cwd: row.cwd, title: row.title });
    }
  }
  return threads;
}

function readString(raw: string, key: string): string | null {
  const match = raw.match(new RegExp(`^${key} = "([^"\\n]*)"$`, "m"));
  return match ? match[1] : null;
}

function readStringArray(raw: string, key: string): string[] {
  const match = raw.match(new RegExp(`^${key} = \\[(.*)\\]$`, "m"));
  if (!match) {
    return [];
  }
  return [...match[1].matchAll(/"([^"\n]*)"/g)].map((item) => item[1]);
}

function isAutomationStatus(value: string): value is AutomationStatus {
  return value === "ACTIVE" || value === "PAUSED";
}

function contextText(kind: string, projectPath: string | null, targetThreadId: string | null, targetThreadTitle?: string): string {
  if (projectPath) {
    return basename(projectPath);
  }
  if (targetThreadTitle) {
    return `${titleCase(kind)} • ${targetThreadTitle}`;
  }
  if (targetThreadId) {
    return `${titleCase(kind)} • ${abbreviated(targetThreadId)}`;
  }
  return titleCase(kind);
}

function scheduleText(status: AutomationStatus, rrule: string): string {
  if (status === "PAUSED") {
    return "Paused";
  }
  const normalized = rrule.replace(/^RRULE:/, "");
  const fields = new Map(normalized.split(";").map((part) => {
    const [key, value] = part.split("=");
    return [key, value];
  }));
  const frequency = fields.get("FREQ");
  const interval = Number(fields.get("INTERVAL") ?? "1");
  if (frequency === "HOURLY") {
    return interval === 1 ? "Hourly" : `Every ${interval}h`;
  }
  if (frequency === "MINUTELY") {
    return `Every ${interval}m`;
  }
  if (frequency === "WEEKLY") {
    return "Weekly";
  }
  return titleCase(frequency?.toLowerCase() ?? "scheduled");
}

function titleCase(value: string): string {
  return value
    .split(/[_\s-]+/)
    .filter(Boolean)
    .map((part) => `${part.slice(0, 1).toUpperCase()}${part.slice(1).toLowerCase()}`)
    .join(" ");
}

function abbreviated(value: string): string {
  return value.length > 18 ? `${value.slice(0, 18)}...` : value;
}
