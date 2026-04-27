import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import { promisify } from "node:util";
import type { NewChatAccessPreset, NewChatOptions, NewChatProject, NewChatReasoning } from "./types.js";

const execFileAsync = promisify(execFile);
const noProjectId = "no-project";
const defaultProjectRoot = join(homedir(), "Documents", "Codex");

export async function getNewChatOptions(projectPath?: string): Promise<NewChatOptions> {
  const config = await readText(join(homedir(), ".codex", "config.toml"));
  const globalState = await readJson(join(homedir(), ".codex", ".codex-global-state.json"));
  const projects = discoverProjects(config, globalState);
  const defaultProjectId = projectPath && projects.some((project) => project.path === projectPath) ? projectPath : projects[0]?.id ?? noProjectId;
  const selectedProject = projects.find((project) => project.id === defaultProjectId);
  const branchRoot = selectedProject?.path ?? projectPath;

  return {
    projects,
    defaultProjectId,
    branches: branchRoot ? await listBranches(branchRoot) : [],
    defaultBranch: branchRoot ? await currentBranch(branchRoot) : "",
    workModes: ["local", "worktree"],
    accessPresets: ["full_access", "on_request", "read_only"],
    defaultAccessPreset: defaultAccessPreset(config),
    models: ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-5.3-codex", "gpt-5.2"],
    defaultModel: readTomlString(config, "model") ?? "gpt-5.5",
    reasoningEfforts: ["low", "medium", "high", "xhigh"],
    defaultReasoningEffort: defaultReasoning(config)
  };
}

export function discoverProjects(config: string, globalState: unknown): NewChatProject[] {
  const paths = [
    ...readGlobalStringArray(globalState, "project-order"),
    ...readGlobalStringArray(globalState, "electron-saved-workspace-roots"),
    ...readConfigProjects(config)
  ];
  const seen = new Set<string>();
  const projects: NewChatProject[] = [{ id: noProjectId, name: "No project", path: null }];
  for (const path of paths) {
    if (seen.has(path)) {
      continue;
    }
    seen.add(path);
    projects.push({ id: path, name: basename(path), path });
  }
  return projects;
}

export async function prepareChatWorkspace(options: { projectPath?: string | null; branch: string; newBranch?: string; workMode: "local" | "worktree" }): Promise<string> {
  const root = options.projectPath || defaultProjectRoot;
  const branch = options.newBranch?.trim() || options.branch.trim();
  if (options.workMode === "local") {
    if (branch) {
      await execFileAsync("git", ["checkout", options.newBranch?.trim() ? "-b" : "", branch].filter(Boolean), { cwd: root });
    }
    return root;
  }
  const worktreeBranch = branch || await currentBranch(root);
  const worktreePath = `${root}-${sanitizeBranchName(worktreeBranch)}-worktree`;
  const args = options.newBranch?.trim()
    ? ["worktree", "add", "-b", worktreeBranch, worktreePath, "HEAD"]
    : ["worktree", "add", worktreePath, worktreeBranch];
  await execFileAsync("git", args, { cwd: root });
  return worktreePath;
}

export function codexAccessArgs(preset: NewChatAccessPreset): string[] {
  switch (preset) {
    case "full_access":
      return ["-s", "danger-full-access", "-a", "never"];
    case "read_only":
      return ["-s", "read-only", "-a", "on-request"];
    case "on_request":
      return ["-s", "workspace-write", "-a", "on-request"];
  }
}

function defaultAccessPreset(config: string): NewChatAccessPreset {
  const sandbox = readTomlString(config, "sandbox") ?? readTomlString(config, "sandbox_mode");
  const approval = readTomlString(config, "ask_for_approval") ?? readTomlString(config, "approval_policy");
  if (sandbox === "danger-full-access" && approval === "never") {
    return "full_access";
  }
  if (sandbox === "read-only") {
    return "read_only";
  }
  return "on_request";
}

function defaultReasoning(config: string): NewChatReasoning {
  const value = readTomlString(config, "model_reasoning_effort");
  return value === "low" || value === "medium" || value === "high" || value === "xhigh" ? value : "high";
}

async function listBranches(repo: string) {
  try {
    const { stdout } = await execFileAsync("git", ["branch", "--format=%(refname:short)|%(HEAD)"], { cwd: repo });
    return stdout.split(/\r?\n/).filter(Boolean).map((line) => {
      const [name, head] = line.split("|");
      return { name, isCurrent: head === "*" };
    });
  } catch {
    return [];
  }
}

async function currentBranch(repo: string): Promise<string> {
  try {
    const { stdout } = await execFileAsync("git", ["branch", "--show-current"], { cwd: repo });
    return stdout.trim();
  } catch {
    return "";
  }
}

async function readText(path: string): Promise<string> {
  try {
    return await readFile(path, "utf8");
  } catch {
    return "";
  }
}

async function readJson(path: string): Promise<unknown> {
  const text = await readText(path);
  if (!text) {
    return {};
  }
  return JSON.parse(text);
}

function readGlobalStringArray(value: unknown, key: string): string[] {
  if (!value || typeof value !== "object") {
    return [];
  }
  const array = (value as Record<string, unknown>)[key];
  return Array.isArray(array) ? array.filter((item): item is string => typeof item === "string" && item.length > 0) : [];
}

function readConfigProjects(config: string): string[] {
  return [...config.matchAll(/^\[projects\."([^"]+)"\]/gm)].map((match) => match[1]);
}

function readTomlString(config: string, key: string): string | undefined {
  const match = config.match(new RegExp(`^${key}\\s*=\\s*"([^"]+)"`, "m"));
  return match?.[1];
}

function sanitizeBranchName(branch: string): string {
  return branch.replace(/[^A-Za-z0-9._-]/g, "-");
}
