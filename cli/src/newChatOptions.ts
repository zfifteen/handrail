import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, join } from "node:path";
import { promisify } from "node:util";
import { grokBinary } from "./grokPaths.js";
import { listGrokChats } from "./grokSessions.js";
import type { NewChatAccessPreset, NewChatOptions, NewChatProject, NewChatReasoning } from "./types.js";

const execFileAsync = promisify(execFile);
const noProjectId = "no-project";
const defaultProjectRoot = join(homedir(), "IdeaProjects");

export async function getNewChatOptions(projectPath?: string): Promise<NewChatOptions> {
  const projects = await discoverGrokProjects();
  const defaultProjectId = projectPath && projects.some((project) => project.path === projectPath)
    ? projectPath
    : projects.find((project) => project.path)?.id ?? noProjectId;
  const selectedProject = projects.find((project) => project.id === defaultProjectId);
  const branchRoot = selectedProject?.path ?? projectPath;

  return {
    projects,
    defaultProjectId,
    branches: branchRoot ? await listBranches(branchRoot) : [],
    defaultBranch: branchRoot ? await currentBranch(branchRoot) : "",
    workModes: ["local", "worktree"],
    accessPresets: ["full_access", "on_request", "read_only"],
    defaultAccessPreset: "on_request",
    models: await listGrokModels(),
    defaultModel: "grok-build",
    reasoningEfforts: ["low", "medium", "high", "xhigh"],
    defaultReasoningEffort: "high"
  };
}

export async function discoverGrokProjects(): Promise<NewChatProject[]> {
  const chats = await listGrokChats();
  const paths = chats.map((chat) => chat.repo).filter((repo) => repo.length > 0);
  return discoverProjectsFromPaths([defaultProjectRoot, ...paths]);
}

export function discoverProjectsFromPaths(paths: string[]): NewChatProject[] {
  const seen = new Set<string>();
  const projects: NewChatProject[] = [{ id: noProjectId, name: "No project", path: null }];
  for (const path of paths) {
    if (!path || seen.has(path)) {
      continue;
    }
    seen.add(path);
    projects.push({ id: path, name: basename(path), path });
  }
  return projects;
}

export async function prepareChatWorkspace(options: {
  projectPath?: string | null;
  branch: string;
  newBranch?: string;
  workMode: "local" | "worktree";
}): Promise<string> {
  const root = options.projectPath || defaultProjectRoot;
  const selectedBranch = options.branch.trim();
  const newBranch = options.newBranch?.trim();
  if (options.workMode === "local") {
    if (newBranch) {
      await execFileAsync("git", ["checkout", "-b", newBranch, selectedBranch || "HEAD"], { cwd: root });
    } else if (selectedBranch) {
      await execFileAsync("git", ["checkout", selectedBranch], { cwd: root });
    }
    return root;
  }
  const worktreeBranch = newBranch || selectedBranch || await currentBranch(root);
  const worktreePath = `${root}-${sanitizeBranchName(worktreeBranch)}-worktree`;
  const args = newBranch
    ? ["worktree", "add", "-b", newBranch, worktreePath, selectedBranch || "HEAD"]
    : ["worktree", "add", worktreePath, worktreeBranch];
  await execFileAsync("git", args, { cwd: root });
  return worktreePath;
}

async function listGrokModels(): Promise<string[]> {
  try {
    const { stdout } = await execFileAsync(grokBinary(), ["models"]);
    const models = [...stdout.matchAll(/^\s*\*?\s*(\S+)/gm)]
      .map((match) => match[1])
      .filter((model) => model !== "Available" && model !== "Default");
    return models.length > 0 ? models : ["grok-build"];
  } catch {
    return ["grok-build"];
  }
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

function sanitizeBranchName(branch: string): string {
  return branch.replace(/[^A-Za-z0-9._-]/g, "-");
}