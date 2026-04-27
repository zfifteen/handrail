import test from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { join } from "node:path";
import { chmod, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { chatArgs, formatAgentOutput, startAgent } from "../src/codex.js";
import { parseDesktopPinnedThreadIds } from "../src/codexSessions.js";
import { desktopThreadPromotion } from "../src/codexDesktop.js";
import { codexDesktopIpcRequest, codexDesktopIpcRequestVersion, encodeCodexDesktopIpcFrame } from "../src/codexDesktopIpc.js";
import { discoverProjects } from "../src/newChatOptions.js";
import { extractCodexThreadId, SessionManager } from "../src/sessions.js";

test("starts configured agent with initial prompt as an argument", async () => {
  const previousCommand = process.env.HANDRAIL_AGENT_COMMAND;
  process.env.HANDRAIL_AGENT_COMMAND = `${process.execPath} ${join(process.cwd(), "test/fixtures/fake-agent.mjs")}`;

  try {
    const agent = startAgent(process.cwd(), "Hello from Handrail");
    let output = "";
    agent.child.stdout.on("data", (chunk: Buffer) => {
      output += chunk.toString();
    });
    const [code] = await once(agent.child, "exit");

    assert.equal(code, 0);
    assert.match(output, /prompt:Hello from Handrail/);
  } finally {
    if (previousCommand === undefined) {
      delete process.env.HANDRAIL_AGENT_COMMAND;
    } else {
      process.env.HANDRAIL_AGENT_COMMAND = previousCommand;
    }
  }
});

test("continues Codex exec sessions with resume id and prompt", async () => {
  const previousCommand = process.env.HANDRAIL_AGENT_COMMAND;
  const tempDir = await mkdtemp(join(tmpdir(), "handrail-codex-"));
  const fakeCodex = join(tempDir, "codex");
  await symlink(join(process.cwd(), "test/fixtures/fake-codex.mjs"), fakeCodex);
  process.env.HANDRAIL_AGENT_COMMAND = `${fakeCodex} exec --json --color never`;

  try {
    const agent = startAgent(process.cwd(), "Continue from phone", "abc-123");
    let output = "";
    agent.child.stdout.on("data", (chunk: Buffer) => {
      output += chunk.toString();
    });
    const [code] = await once(agent.child, "exit");

    assert.equal(code, 0);
    assert.match(output, /args:exec\|resume\|--json\|abc-123\|Continue from phone/);
  } finally {
    await rm(tempDir, { recursive: true, force: true });
    if (previousCommand === undefined) {
      delete process.env.HANDRAIL_AGENT_COMMAND;
    } else {
      process.env.HANDRAIL_AGENT_COMMAND = previousCommand;
    }
  }
});

test("maps new chat options into Codex exec arguments", async () => {
  const previousCommand = process.env.HANDRAIL_AGENT_COMMAND;
  const tempDir = await mkdtemp(join(tmpdir(), "handrail-codex-"));
  const fakeCodex = join(tempDir, "codex");
  await symlink(join(process.cwd(), "test/fixtures/fake-codex.mjs"), fakeCodex);
  process.env.HANDRAIL_AGENT_COMMAND = `${fakeCodex} exec --json --color never`;

  try {
    const agent = startAgent(process.cwd(), "Build it", undefined, {
      model: "gpt-5.5",
      reasoningEffort: "high",
      accessPreset: "full_access",
      skipGitRepoCheck: true
    });
    let output = "";
    agent.child.stdout.on("data", (chunk: Buffer) => {
      output += chunk.toString();
    });
    const [code] = await once(agent.child, "exit");

    assert.equal(code, 0);
    assert.match(output, /args:exec\|--json\|--color\|never\|--skip-git-repo-check\|-m\|gpt-5\.5\|-c\|model_reasoning_effort=\\?"high\\?"\|-s\|danger-full-access\|-a\|never\|Build it/);
  } finally {
    await rm(tempDir, { recursive: true, force: true });
    if (previousCommand === undefined) {
      delete process.env.HANDRAIL_AGENT_COMMAND;
    } else {
      process.env.HANDRAIL_AGENT_COMMAND = previousCommand;
    }
  }
});

test("discovers New Chat projects from Codex Desktop state and config", () => {
  const projects = discoverProjects(
    '[projects."/Users/me/config-project"]\ntrust_level = "trusted"\n',
    {
      "project-order": ["/Users/me/ordered"],
      "electron-saved-workspace-roots": ["/Users/me/ordered", "/Users/me/saved"]
    }
  );

  assert.deepEqual(projects, [
    { id: "no-project", name: "No project", path: null },
    { id: "/Users/me/ordered", name: "ordered", path: "/Users/me/ordered" },
    { id: "/Users/me/saved", name: "saved", path: "/Users/me/saved" },
    { id: "/Users/me/config-project", name: "config-project", path: "/Users/me/config-project" }
  ]);
});

test("constructs Codex chat argument presets", () => {
  assert.deepEqual(chatArgs(["exec", "--json", "--color", "never"], {
    model: "gpt-5.5",
    reasoningEffort: "xhigh",
    accessPreset: "read_only",
    skipGitRepoCheck: true
  }), [
    "exec",
    "--json",
    "--color",
    "never",
    "--skip-git-repo-check",
    "-m",
    "gpt-5.5",
    "-c",
    "model_reasoning_effort=\"xhigh\"",
    "-s",
    "read-only",
    "-a",
    "on-request"
  ]);
});

test("formats Codex JSON events into readable transcript lines", () => {
  const output = formatAgentOutput([
    "{\"type\":\"thread.started\",\"thread_id\":\"abc\"}",
    "{\"type\":\"turn.started\"}",
    "2026-04-25T09:43:20.843471Z  WARN codex_core::plugins::manifest: noisy startup warning",
    "<head><meta name=\"viewport\" /></head><body>challenge</body></html>",
    "{\"type\":\"item.completed\",\"item\":{\"type\":\"agent_message\",\"text\":\"done\"}}",
    "{\"type\":\"error\",\"message\":\"{\\\"error\\\":{\\\"message\\\":\\\"boom\\\"}}\"}"
  ].join("\n"));

  assert.equal(output, [
    "Codex thread started: abc",
    "Codex started.",
    "done",
    "Codex error: boom"
  ].join("\n"));
});

test("extracts Codex thread id from formatted subprocess output", () => {
  assert.equal(
    extractCodexThreadId("Codex thread started: 019dc424-e857-76e0-8229-589ecf107eb4\nCodex started."),
    "019dc424-e857-76e0-8229-589ecf107eb4"
  );
  assert.equal(extractCodexThreadId("Codex started."), null);
});

test("builds deterministic desktop thread promotion SQL", () => {
  const promotion = desktopThreadPromotion(
    "019dc424-e857-76e0-8229-589ecf107eb4",
    "Phone prompt",
    "Phone prompt body",
    1_777_268_840_434
  );

  assert.match(promotion.databasePath, /\.codex\/state_5\.sqlite$/);
  assert.match(promotion.sql, /UPDATE threads SET source = \?/);
  assert.deepEqual(promotion.args, [
    "vscode",
    "Phone prompt",
    "Phone prompt body",
    "1777268840",
    "1777268840",
    "1777268840434",
    "1777268840434",
    "019dc424-e857-76e0-8229-589ecf107eb4"
  ]);
});

test("builds Codex Desktop IPC follower requests", () => {
  const request = codexDesktopIpcRequest(
    "thread-follower-start-turn",
    {
      conversationId: "019dc424-e857-76e0-8229-589ecf107eb4",
      turnStartParams: {
        input: [{ type: "text", text: "Continue from phone", text_elements: [] }],
        cwd: "/Users/me/project"
      }
    },
    "client-1",
    "request-1"
  );

  assert.equal(codexDesktopIpcRequestVersion("initialize"), 0);
  assert.equal(codexDesktopIpcRequestVersion("thread-follower-start-turn"), 1);
  assert.deepEqual(request, {
    type: "request",
    requestId: "request-1",
    sourceClientId: "client-1",
    version: 1,
    method: "thread-follower-start-turn",
    params: {
      conversationId: "019dc424-e857-76e0-8229-589ecf107eb4",
      turnStartParams: {
        input: [{ type: "text", text: "Continue from phone", text_elements: [] }],
        cwd: "/Users/me/project"
      }
    }
  });
});

test("encodes Codex Desktop IPC frames with little-endian length prefix", () => {
  const frame = encodeCodexDesktopIpcFrame({ type: "request", method: "initialize" });
  const length = frame.readUInt32LE(0);

  assert.equal(length, frame.length - 4);
  assert.equal(frame.subarray(4).toString("utf8"), "{\"type\":\"request\",\"method\":\"initialize\"}");
});

test("stop immediately persists and broadcasts stopped status", async () => {
  const previousHome = process.env.HOME;
  const previousCommand = process.env.HANDRAIL_AGENT_COMMAND;
  const tempDir = await mkdtemp(join(tmpdir(), "handrail-stop-"));
  const agentPath = join(tempDir, "agent");
  await writeFile(agentPath, "#!/bin/sh\nsleep 30\n", "utf8");
  await chmod(agentPath, 0o755);
  process.env.HOME = tempDir;
  process.env.HANDRAIL_AGENT_COMMAND = agentPath;

  const messages: unknown[] = [];
  try {
    const manager = new SessionManager((message) => messages.push(message));
    const session = await manager.start(tempDir, "Stop me", "hello");
    await manager.stop(session.id);

    const state = JSON.parse(await readFile(join(tempDir, ".handrail", "state.json"), "utf8"));
    assert.equal(state.sessions[0].id, session.id);
    assert.equal(state.sessions[0].status, "stopped");
    assert.ok(messages.some((message) => {
      const record = message as { type?: string; event?: { kind?: string; status?: string } };
      return record.type === "session_event" &&
        record.event?.kind === "session_stopped" &&
        record.event?.status === "stopped";
    }));
  } finally {
    if (previousHome === undefined) {
      delete process.env.HOME;
    } else {
      process.env.HOME = previousHome;
    }
    if (previousCommand === undefined) {
      delete process.env.HANDRAIL_AGENT_COMMAND;
    } else {
      process.env.HANDRAIL_AGENT_COMMAND = previousCommand;
    }
    await rm(tempDir, { recursive: true, force: true });
  }
});

test("reads Codex Desktop pinned thread ids", () => {
  const pinned = parseDesktopPinnedThreadIds(JSON.stringify({
    "pinned-thread-ids": [
      "019dc36a-1b28-73c0-8250-cd67ed5c26a5",
      42,
      "",
      "019dcae8-b6b6-7823-afe4-c7da97e7ea53"
    ]
  }));

  assert.deepEqual([...pinned], [
    ["019dc36a-1b28-73c0-8250-cd67ed5c26a5", 0],
    ["019dcae8-b6b6-7823-afe4-c7da97e7ea53", 3]
  ]);
});
