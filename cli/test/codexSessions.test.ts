import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { desktopProjectName, formatCodexTranscriptEntry, readRolloutLines, visibleDesktopThreads, type CodexDesktopThreadRow } from "../src/codexSessions.js";

test("formats imported Codex transcript entries for rich mobile rendering", () => {
  const entry = formatCodexTranscriptEntry("assistant", [
    "Yes, but only if SOUL.md has a different contract from AGENTS.md.",
    "A good split would be:",
    "",
    "```md",
    "# SOUL.md",
    "```",
    "",
    "- Preserve purpose.",
    "- Avoid drift."
  ].join("\n"));

  assert.equal(entry, [
    "Codex:",
    "Yes, but only if SOUL.md has a different contract from AGENTS.md.  ",
    "A good split would be:  ",
    "",
    "```md",
    "# SOUL.md",
    "```",
    "",
    "- Preserve purpose.  ",
    "- Avoid drift.  ",
    "",
    ""
  ].join("\n"));
});

test("imports only visible desktop chat rows", () => {
  const rows: CodexDesktopThreadRow[] = [
    row("visible", "Visible Desktop Chat", 10, 0, "vscode", "Hello"),
    row("empty", "Generated Interrupted Chat", 30, 0, "vscode", "   "),
    row("archived", "Archived Chat", 40, 1, "vscode", "Hello"),
    row("exec", "CLI Smoke", 50, 0, "exec", "Hello"),
    row("newer-visible", "Newer Visible Desktop Chat", 20, 0, "vscode", "Hello")
  ];

  assert.deepEqual(visibleDesktopThreads(rows), [
    {
      id: "newer-visible",
      rollout_path: "/tmp/newer-visible.jsonl",
      cwd: "/tmp/project",
      title: "Newer Visible Desktop Chat",
      created_at: 1,
      updated_at: 20
    },
    {
      id: "visible",
      rollout_path: "/tmp/visible.jsonl",
      cwd: "/tmp/project",
      title: "Visible Desktop Chat",
      created_at: 1,
      updated_at: 10
    }
  ]);
});

test("uses Codex Desktop project names for imported chat metadata", () => {
  const projects = new Map([
    ["/Users/me/IdeaProjects/handrail", "Build Handrail MVP"]
  ]);

  assert.equal(desktopProjectName("/Users/me/IdeaProjects/handrail", projects), "Build Handrail MVP");
  assert.equal(desktopProjectName("/Users/me/IdeaProjects/pgs_lab", projects), "pgs_lab");
});

test("reads large Codex rollout files from bounded head and tail", async () => {
  const tempDir = await mkdtemp(join(tmpdir(), "handrail-rollout-"));
  const path = join(tempDir, "rollout.jsonl");
  const first = JSON.stringify({ type: "session_meta", payload: { id: "abc", timestamp: "2026-04-28T00:00:00.000Z" } });
  const last = JSON.stringify({ timestamp: "2026-04-28T00:01:00.000Z", type: "response_item", payload: { type: "message", role: "assistant", content: [{ type: "output_text", text: "tail message" }] } });
  const filler = `${JSON.stringify({ type: "filler", payload: "x".repeat(2048) })}\n`.repeat(1200);
  await writeFile(path, `${first}\n${filler}${last}\n`, "utf8");

  try {
    const lines = await readRolloutLines(path);
    assert.equal(lines[0], first);
    assert.equal(lines.at(-1), last);
    assert.ok(lines.join("\n").length < 2_200_000);
  } finally {
    await rm(tempDir, { recursive: true, force: true });
  }
});

function row(id: string, title: string, updatedAt: number, archived: number, source: string, firstUserMessage: string): CodexDesktopThreadRow {
  return {
    id,
    rollout_path: `/tmp/${id}.jsonl`,
    cwd: "/tmp/project",
    title,
    created_at: 1,
    updated_at: updatedAt,
    archived,
    source,
    first_user_message: firstUserMessage
  };
}
