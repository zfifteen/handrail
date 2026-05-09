import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { desktopProjectName, extractStatus, extractThinking, extractTranscript, formatCodexTranscriptEntry, humanCodexTitle, latestCodexLogStatuses, parseAutomationTargetThreadId, readCodexSessionStatus, readRolloutLines, visibleDesktopThreads, type CodexDesktopThreadRow } from "../src/codexSessions.js";

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

test("does not import commentary assistant messages as transcript blocks", () => {
  const lines = [
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "user", content: [{ type: "input_text", text: "Proceed" }] }
    }),
    JSON.stringify({
      type: "response_item",
      payload: {
        type: "message",
        role: "assistant",
        phase: "commentary",
        content: [{ type: "output_text", text: "I am checking the simulator now." }]
      }
    }),
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "assistant", content: [{ type: "output_text", text: "The implementation is complete." }] }
    })
  ];

  assert.deepEqual(extractTranscript(lines), [
    formatCodexTranscriptEntry("user", "Proceed"),
    formatCodexTranscriptEntry("assistant", "The implementation is complete.")
  ]);
});

test("does not import subagent notifications as visible transcript blocks", () => {
  const lines = [
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "user", content: [{ type: "input_text", text: "Check the release" }] }
    }),
    JSON.stringify({
      type: "response_item",
      payload: {
        type: "message",
        role: "user",
        content: [{ type: "input_text", text: "<subagent_notification>\n{\"status\":{\"completed\":\"large internal payload\"}}\n</subagent_notification>" }]
      }
    }),
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "assistant", phase: "final_answer", content: [{ type: "output_text", text: "Release check complete." }] }
    })
  ];

  assert.deepEqual(extractTranscript(lines), [
    formatCodexTranscriptEntry("user", "Check the release"),
    formatCodexTranscriptEntry("assistant", "Release check complete.")
  ]);
  assert.equal(extractThinking(lines).length, 0);
});

test("preserves long assistant transcript entries without truncation markers", () => {
  const text = `long answer ${"x".repeat(3_000)}`;
  const transcript = extractTranscript([
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "assistant", content: [{ type: "output_text", text }] }
    })
  ]);

  assert.equal(transcript.length, 1);
  assert.ok(transcript[0].includes(text));
  assert.equal(transcript[0].includes("[truncated]"), false);
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
      first_user_message: "Hello",
      created_at: 1,
      updated_at: 20
    },
    {
      id: "visible",
      rollout_path: "/tmp/visible.jsonl",
      cwd: "/tmp/project",
      title: "Visible Desktop Chat",
      first_user_message: "Hello",
      created_at: 1,
      updated_at: 10
    }
  ]);
});

test("normalizes raw Codex thread ids out of user-visible chat titles", () => {
  assert.equal(
    humanCodexTitle(
      "codex:019dd5d6-86b5-7081-8d93-318872cfb02a",
      null,
      "What should we build in Handrail?",
      "/Users/me/IdeaProjects/handrail"
    ),
    "What should we build in Handrail?"
  );
  assert.equal(
    humanCodexTitle(
      "019dd5d6-86b5-7081-8d93-318872cfb02a",
      "Build Handrail MVP",
      "What should we build?",
      "/Users/me/IdeaProjects/handrail"
    ),
    "Build Handrail MVP"
  );
  assert.equal(
    humanCodexTitle("Build Handrail MVP", "Ignored", "Ignored", "/Users/me/IdeaProjects/handrail"),
    "Build Handrail MVP"
  );
});

test("uses Codex Desktop project names for imported chat metadata", () => {
  const projects = new Map([
    ["/Users/me/IdeaProjects/handrail", "Build Handrail MVP"]
  ]);

  assert.equal(desktopProjectName("/Users/me/IdeaProjects/handrail", projects), "Build Handrail MVP");
  assert.equal(desktopProjectName("/Users/me/IdeaProjects/pgs_lab", projects), "pgs_lab");
});

test("uses the newest SQLite lifecycle status per Codex thread", () => {
  assert.deepEqual(latestCodexLogStatuses([
    { thread_id: "active", status: "completed", ts: 10, ts_nanos: 0, id: 1 },
    { thread_id: "done", status: "running", ts: 7, ts_nanos: 0, id: 2 },
    { thread_id: "active", status: "running", ts: 11, ts_nanos: 0, id: 3 },
    { thread_id: "done", status: "completed", ts: 7, ts_nanos: 1, id: 4 },
    { thread_id: "failed", status: "failed", ts: 12, ts_nanos: 0, id: 5 }
  ]), new Map([
    ["active", "running"],
    ["done", "completed"],
    ["failed", "failed"]
  ]));
});

test("extracts automation target thread ids from automation TOML", () => {
  assert.equal(
    parseAutomationTargetThreadId([
      "version = 1",
      "id = \"handrail-new-features\"",
      "target_thread_id = \"019ddd78-6bd2-7133-b9eb-bbf561cdc100\""
    ].join("\n")),
    "019ddd78-6bd2-7133-b9eb-bbf561cdc100"
  );
  assert.equal(parseAutomationTargetThreadId("version = 1\nid = \"unbound\"\n"), null);
});

test("extracts desktop thinking summaries by visible chat round", () => {
  const lines = [
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "user", content: [{ type: "input_text", text: "First prompt" }] }
    }),
    JSON.stringify({
      timestamp: "2026-04-30T00:00:01.000Z",
      type: "event_msg",
      payload: { type: "agent_reasoning", text: "Thinking about the first prompt." }
    }),
    JSON.stringify({
      type: "response_item",
      payload: {
        type: "reasoning",
        summary: [{ type: "summary_text", text: "Duplicate reasoning item." }],
        encrypted_content: "ignored"
      }
    }),
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "assistant", content: [{ type: "output_text", text: "First answer" }] }
    }),
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "user", content: [{ type: "input_text", text: "Second prompt" }] }
    }),
    JSON.stringify({
      timestamp: "2026-04-30T00:00:02.000Z",
      type: "event_msg",
      payload: { type: "agent_reasoning", text: "Thinking about the second prompt." }
    })
  ];

  assert.deepEqual(extractThinking(lines), [
    {
      id: "thinking:1:2026-04-30T00:00:01.000Z",
      round: 1,
      text: "Thinking about the first prompt.  ",
      at: "2026-04-30T00:00:01.000Z"
    },
    {
      id: "thinking:5:2026-04-30T00:00:02.000Z",
      round: 2,
      text: "Thinking about the second prompt.  ",
      at: "2026-04-30T00:00:02.000Z"
    }
  ]);
});

test("extracts commentary agent messages as thinking entries", () => {
  const lines = [
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "user", content: [{ type: "input_text", text: "Fix the chat screen" }] }
    }),
    JSON.stringify({
      timestamp: "2026-05-06T00:00:01.000Z",
      type: "event_msg",
      payload: {
        type: "agent_message",
        phase: "commentary",
        message: "I am reproducing the iOS simulator behavior before editing."
      }
    })
  ];

  assert.deepEqual(extractThinking(lines), [
    {
      id: "thinking:1:2026-05-06T00:00:01.000Z",
      round: 1,
      text: "I am reproducing the iOS simulator behavior before editing.  ",
      at: "2026-05-06T00:00:01.000Z"
    }
  ]);
});

test("routes desktop worked stream to thinking while preserving final answer transcript", () => {
  const lines = [
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "user", content: [{ type: "input_text", text: "Run OODA" }] }
    }),
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "user", content: [{ type: "input_text", text: "<skill>\n<name>ooda</name>\n</skill>" }] }
    }),
    JSON.stringify({
      timestamp: "2026-05-06T11:42:00.000Z",
      type: "event_msg",
      payload: {
        type: "agent_message",
        phase: "commentary",
        message: "I am checking the current v2 evidence before answering."
      }
    }),
    JSON.stringify({
      type: "response_item",
      payload: {
        type: "message",
        role: "assistant",
        phase: "commentary",
        content: [{ type: "output_text", text: "I am checking the current v2 evidence before answering." }]
      }
    }),
    JSON.stringify({
      timestamp: "2026-05-06T11:42:01.000Z",
      type: "response_item",
      payload: {
        type: "function_call",
        name: "exec_command",
        call_id: "call-1",
        arguments: "{\"cmd\":\"rg -n inner_miss\"}"
      }
    }),
    JSON.stringify({
      timestamp: "2026-05-06T11:42:02.000Z",
      type: "response_item",
      payload: {
        type: "function_call_output",
        call_id: "call-1",
        output: "Chunk ID: abc\nOutput:\ninner_miss=9"
      }
    }),
    JSON.stringify({
      timestamp: "2026-05-06T11:42:03.000Z",
      type: "event_msg",
      payload: {
        type: "exec_command_end",
        call_id: "call-1",
        command: ["/bin/zsh", "-lc", "rg -n inner_miss"],
        exit_code: 0,
        aggregated_output: "inner_miss=9"
      }
    }),
    JSON.stringify({
      timestamp: "2026-05-06T11:42:04.000Z",
      type: "response_item",
      payload: {
        type: "custom_tool_call",
        name: "apply_patch",
        call_id: "call-2",
        input: "*** Begin Patch\n*** Update File: memory.md"
      }
    }),
    JSON.stringify({
      timestamp: "2026-05-06T11:42:05.000Z",
      type: "event_msg",
      payload: {
        type: "patch_apply_end",
        call_id: "call-2",
        success: true,
        stdout: "Success. Updated the following files:\nM memory.md"
      }
    }),
    JSON.stringify({
      timestamp: "2026-05-06T11:42:06.000Z",
      type: "response_item",
      payload: {
        type: "message",
        role: "assistant",
        phase: "final_answer",
        content: [{ type: "output_text", text: "Observe: The final answer remains visible." }]
      }
    })
  ];

  const transcript = extractTranscript(lines);
  assert.deepEqual(transcript, [
    formatCodexTranscriptEntry("user", "Run OODA"),
    formatCodexTranscriptEntry("assistant", "Observe: The final answer remains visible.")
  ]);
  assert.equal(transcript.some((entry) => entry.includes("<skill>")), false);
  assert.equal(transcript.some((entry) => entry.includes("Chunk ID:")), false);

  const thinking = extractThinking(lines);
  assert.equal(thinking.every((entry) => entry.round === 1), true);
  assert.ok(thinking.some((entry) => entry.text.includes("checking the current v2 evidence")));
  assert.ok(thinking.some((entry) => entry.text.includes("Tool call: exec_command")));
  assert.ok(thinking.some((entry) => entry.text.includes("Tool result")));
  assert.ok(thinking.some((entry) => entry.text.includes("Command completed")));
  assert.ok(thinking.some((entry) => entry.text.includes("Tool call: apply_patch")));
  assert.ok(thinking.some((entry) => entry.text.includes("Patch applied")));
}
);

test("imports content-array tool outputs as thinking without dropping transcript detail", () => {
  const lines = [
    JSON.stringify({
      type: "response_item",
      payload: { type: "message", role: "user", content: [{ type: "input_text", text: "Can you install it for me?" }] }
    }),
    JSON.stringify({
      timestamp: "2026-05-03T13:18:26.000Z",
      type: "response_item",
      payload: {
        type: "function_call_output",
        call_id: "call-1",
        output: [
          { type: "input_text", text: "Created automation in the app." },
          { type: "input_text", text: "{\"automationId\":\"rsa-v2-40-bit-pgs-research-loop\",\"mode\":\"create\"}" }
        ]
      }
    }),
    JSON.stringify({
      timestamp: "2026-05-03T13:18:44.000Z",
      type: "response_item",
      payload: {
        type: "message",
        role: "assistant",
        phase: "final_answer",
        content: [{ type: "output_text", text: "Installed `hatch-pet`." }]
      }
    })
  ];

  const thinking = extractThinking(lines);
  assert.equal(thinking.length, 1);
  assert.ok(thinking[0].text.includes("Created automation in the app."));
  assert.ok(thinking[0].text.includes("rsa-v2-40-bit-pgs-research-loop"));
  assert.deepEqual(extractTranscript(lines), [
    formatCodexTranscriptEntry("user", "Can you install it for me?"),
    formatCodexTranscriptEntry("assistant", "Installed `hatch-pet`.")
  ]);
});

test("bounds extracted thinking summaries", () => {
  const lines = Array.from({ length: 45 }, (_, index) => JSON.stringify({
    timestamp: `2026-04-30T00:00:${String(index).padStart(2, "0")}.000Z`,
    type: "event_msg",
    payload: { type: "agent_reasoning", text: `thinking ${index} ${"x".repeat(400)}` }
  }));

  const thinking = extractThinking(lines);
  assert.ok(thinking.length < 40);
  assert.ok(thinking.reduce((total, entry) => total + entry.text.length, 0) <= 12_000);
  assert.equal(thinking.at(-1)?.round, 1);
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

test("infers active Codex status when the bounded tail omits task_started", async () => {
  const tempDir = await mkdtemp(join(tmpdir(), "handrail-rollout-status-"));
  const path = join(tempDir, "rollout.jsonl");
  const first = JSON.stringify({ type: "session_meta", payload: { id: "abc", timestamp: "2026-04-28T00:00:00.000Z" } });
  const started = JSON.stringify({ timestamp: "2026-04-28T00:00:01.000Z", type: "event_msg", payload: { type: "task_started" } });
  const fillerLine = JSON.stringify({ timestamp: "2026-04-28T00:00:02.000Z", type: "event_msg", payload: { type: "token_count", text: "x".repeat(2048) } });
  const filler = `${fillerLine}\n`.repeat(1200);
  await writeFile(path, `${first}\n${started}\n${filler}`, "utf8");

  try {
    const boundedLines = await readRolloutLines(path);
    assert.equal(extractStatus(boundedLines.slice(1)), "running");
    assert.equal(await readCodexSessionStatus(path), "running");
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
