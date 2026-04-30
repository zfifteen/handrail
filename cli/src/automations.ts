import { access, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { basename, join } from "node:path";
import { homedir } from "node:os";
import type { AutomationRecord, AutomationStatus, ChatRecord, NewChatReasoning, StartChatOptions } from "./types.js";

interface AutomationChatController {
  startChat(options: StartChatOptions): Promise<ChatRecord>;
  continue(chatId: string, prompt: string): Promise<ChatRecord>;
}

export async function listDesktopAutomations(): Promise<AutomationRecord[]> {
  const automationRoot = desktopAutomationRoot();
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

export async function runDesktopAutomationNow(id: string, chats: AutomationChatController): Promise<void> {
  const automation = await readDesktopAutomation(id);
  if (automation.targetThreadId) {
    await chats.continue(`codex:${automation.targetThreadId}`, automation.prompt);
    return;
  }
  if (!automation.model || !automation.reasoningEffort || automation.cwds.length === 0) {
    throw new Error(`Automation ${id} is missing the model, reasoning effort, or workspace required to run now.`);
  }
  if ((automation.executionEnvironment ?? "local") !== "local") {
    throw new Error(`Automation ${id} uses unsupported execution environment ${automation.executionEnvironment}.`);
  }
  await chats.startChat({
    prompt: automation.prompt,
    projectId: automation.cwds[0],
    projectPath: automation.cwds[0],
    workMode: "local",
    branch: "",
    accessPreset: "full_access",
    model: automation.model,
    reasoningEffort: automation.reasoningEffort
  });
}

export async function pauseDesktopAutomation(id: string): Promise<void> {
  const path = desktopAutomationTomlPath(id);
  const raw = await readFile(path, "utf8");
  if (!/^status = "(ACTIVE|PAUSED)"$/m.test(raw)) {
    throw new Error(`Automation ${id} has no status field.`);
  }
  const updated = raw
    .replace(/^status = "ACTIVE"$/m, "status = \"PAUSED\"")
    .replace(/^updated_at = \d+$/m, `updated_at = ${Date.now()}`);
  await writeFile(path, updated, "utf8");
}

export async function deleteDesktopAutomation(id: string): Promise<void> {
  await rm(desktopAutomationPath(id), { recursive: true });
}

export function parseAutomationToml(
  raw: string,
  targetThreads: Map<string, AutomationTargetThread> = new Map()
): AutomationRecord | null {
  const id = readString(raw, "id");
  const name = readString(raw, "name");
  const kind = readString(raw, "kind");
  const prompt = readString(raw, "prompt");
  const status = readString(raw, "status");
  const rrule = readString(raw, "rrule");
  if (!id || !name || !kind || !prompt || !status || !rrule || !isAutomationStatus(status)) {
    return null;
  }

  const cwds = readStringArray(raw, "cwds");
  const targetThreadId = readString(raw, "target_thread_id");
  const model = readString(raw, "model");
  const reasoningEffort = readString(raw, "reasoning_effort");
  const executionEnvironment = readString(raw, "execution_environment");
  const targetThread = targetThreadId ? targetThreads.get(targetThreadId) : undefined;
  const projectPath = cwds[0] ?? targetThread?.cwd ?? null;
  return {
    id,
    name,
    kind,
    status,
    prompt,
    rrule,
    scheduleText: scheduleText(status, rrule),
    contextText: contextText(kind, cwds[0] ?? null, targetThreadId, targetThread?.title),
    projectName: projectPath ? basename(projectPath) : undefined,
    targetThreadId: targetThreadId ?? undefined,
    model: model ?? undefined,
    reasoningEffort: isNewChatReasoning(reasoningEffort) ? reasoningEffort : undefined,
    executionEnvironment: executionEnvironment ?? undefined,
    cwds
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
  const match = raw.match(new RegExp(`^${key} = "((?:\\\\.|[^"\\\\\\n])*)"$`, "m"));
  if (!match) {
    return null;
  }
  try {
    return JSON.parse(`"${match[1]}"`) as string;
  } catch {
    return null;
  }
}

function readStringArray(raw: string, key: string): string[] {
  const match = raw.match(new RegExp(`^${key} = \\[(.*)\\]$`, "m"));
  if (!match) {
    return [];
  }
  return [...match[1].matchAll(/"((?:\\.|[^"\\\n])*)"/g)].map((item) => {
    try {
      return JSON.parse(`"${item[1]}"`) as string;
    } catch {
      return "";
    }
  }).filter(Boolean);
}

function isAutomationStatus(value: string): value is AutomationStatus {
  return value === "ACTIVE" || value === "PAUSED";
}

function isNewChatReasoning(value: string | null): value is NewChatReasoning {
  return value === "low" || value === "medium" || value === "high" || value === "xhigh";
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

async function readDesktopAutomation(id: string): Promise<AutomationRecord> {
  const record = parseAutomationToml(await readFile(desktopAutomationTomlPath(id), "utf8"), await readAutomationTargetThreads());
  if (!record) {
    throw new Error(`Automation ${id} could not be read.`);
  }
  return record;
}

function desktopAutomationRoot(): string {
  return join(process.env.CODEX_HOME ?? join(homedir(), ".codex"), "automations");
}

function desktopAutomationPath(id: string): string {
  if (id.includes("/") || id.includes("\\")) {
    throw new Error(`Invalid automation id ${id}.`);
  }
  return join(desktopAutomationRoot(), id);
}

function desktopAutomationTomlPath(id: string): string {
  return join(desktopAutomationPath(id), "automation.toml");
}
