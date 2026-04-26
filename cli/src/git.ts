import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

export interface GitDiffSnapshot {
  files: string[];
  stat: string;
  diff: string;
}

export async function readGitDiff(repo: string): Promise<GitDiffSnapshot> {
  const [nameOnly, stat, diff] = await Promise.all([
    execFileAsync("git", ["-C", repo, "diff", "--name-only"], { maxBuffer: 2_000_000 }),
    execFileAsync("git", ["-C", repo, "diff", "--stat"], { maxBuffer: 2_000_000 }),
    execFileAsync("git", ["-C", repo, "diff"], { maxBuffer: 5_000_000 })
  ]);

  return {
    files: nameOnly.stdout.split("\n").map((line) => line.trim()).filter(Boolean),
    stat: stat.stdout.trim(),
    diff: diff.stdout
  };
}
