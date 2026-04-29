import test from "node:test";
import assert from "node:assert/strict";
import { EventEmitter, once } from "node:events";
import { join } from "node:path";
import { mkdtemp, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { chatArgs, formatAgentOutput, startAgent } from "../src/codex.js";
import { parseDesktopPinnedThreadIds } from "../src/codexSessions.js";
import { desktopThreadPromotion } from "../src/codexDesktop.js";
import { codexDesktopIpcRequest, codexDesktopIpcRequestVersion, codexDesktopThreadUrl, encodeCodexDesktopIpcFrame } from "../src/codexDesktopIpc.js";
import { discoverProjects } from "../src/newChatOptions.js";
import { ChatManager, extractCodexThreadId } from "../src/chats.js";

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

test("continues Codex chats with resume id and prompt", async () => {
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
    assert.match(output, /args:exec\|--json\|--color\|never\|--skip-git-repo-check\|-m\|gpt-5\.5\|-c\|model_reasoning_effort=\\?"high\\?"\|-s\|danger-full-access\|-c\|approval_policy=\\?"never\\?"\|Build it/);
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
    "-c",
    "approval_policy=\"on-request\""
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
    "Phone prompt's body",
    1_777_268_840_434,
    {
      cwd: "/Users/me/project",
      rolloutPath: "/Users/me/.codex/sessions/rollout-019dc424-e857-76e0-8229-589ecf107eb4.jsonl",
      model: "gpt-5.5",
      reasoningEffort: "high",
      sandboxPolicy: "read-only",
      approvalMode: "on-request"
    }
  );

  assert.match(promotion.databasePath, /\.codex\/state_5\.sqlite$/);
  assert.match(promotion.sql, /INSERT INTO threads/);
  assert.match(promotion.sql, /\/Users\/me\/\.codex\/sessions\/rollout-019dc424-e857-76e0-8229-589ecf107eb4\.jsonl/);
  assert.match(promotion.sql, /UPDATE threads SET source = 'vscode'/);
  assert.match(promotion.sql, /title = CASE WHEN title = '' OR source = 'exec' THEN 'Phone prompt' ELSE title END/);
  assert.match(promotion.sql, /first_user_message = CASE WHEN first_user_message = '' THEN 'Phone prompt''s body' ELSE first_user_message END/);
  assert.match(promotion.sql, /updated_at = CASE WHEN updated_at < 1777268840 THEN 1777268840 ELSE updated_at END/);
  assert.match(promotion.sql, /WHERE id = '019dc424-e857-76e0-8229-589ecf107eb4'/);
  assert.match(promotion.sql, /SELECT COUNT\(\*\) FROM threads/);
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

test("builds Codex Desktop thread deeplinks", () => {
  assert.equal(
    codexDesktopThreadUrl("019dc424-e857-76e0-8229-589ecf107eb4"),
    "codex://threads/019dc424-e857-76e0-8229-589ecf107eb4"
  );
});

test("encodes Codex Desktop IPC frames with little-endian length prefix", () => {
  const frame = encodeCodexDesktopIpcFrame({ type: "request", method: "initialize" });
  const length = frame.readUInt32LE(0);

  assert.equal(length, frame.length - 4);
  assert.equal(frame.subarray(4).toString("utf8"), "{\"type\":\"request\",\"method\":\"initialize\"}");
});

test("chat manager refuses non-Codex chat ids", async () => {
  const manager = new ChatManager(() => {});
  await assert.rejects(
    () => manager.stop("local-process-id"),
    /No Codex chat with id local-process-id/
  );
});

test("new chat creation promotes the Codex thread into a Desktop-visible chat", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  const messages: unknown[] = [];
  const promoted: Array<{ threadId: string; title: string; firstUserMessage: string }> = [];
  const opened: string[] = [];
  const stdout = new EventEmitter();
  const stderr = new EventEmitter();
  const child = new EventEmitter() as EventEmitter & { stdout: EventEmitter; stderr: EventEmitter };
  child.stdout = stdout;
  child.stderr = stderr;
  let desktopChats = [] as Awaited<ReturnType<ChatManager["list"]>>;

  const manager = new ChatManager((message) => messages.push(JSON.parse(JSON.stringify(message))), {
    listCodexChats: async () => desktopChats,
    prepareChatWorkspace: async (options) => {
      assert.equal(options.projectPath, "/Users/me/project");
      assert.equal(options.branch, "main");
      assert.equal(options.workMode, "local");
      return "/Users/me/project";
    },
    startAgent: (repo, prompt, resumeSessionId, options) => {
      assert.equal(repo, "/Users/me/project");
      assert.equal(prompt, "Phone-created Codex chat");
      assert.equal(resumeSessionId, undefined);
      assert.ok(options);
      assert.equal(options.model, "gpt-5.5");
      assert.equal(options.reasoningEffort, "high");
      assert.equal(options.accessPreset, "on_request");
      assert.equal(options.skipGitRepoCheck, false);
      process.nextTick(() => {
        stdout.emit("data", Buffer.from([
          JSON.stringify({ type: "thread.started", thread_id: threadId }),
          JSON.stringify({ type: "turn.started" }),
          JSON.stringify({ type: "item.completed", item: { type: "agent_message", text: "Created from Desktop-visible Codex." } })
        ].join("\n")));
        child.emit("exit", 0);
      });
      return {
        child,
        acceptsInput: false,
        send() {},
        stop() {}
      } as never;
    },
    promoteCodexThreadToDesktop: async (id, title, firstUserMessage, metadata) => {
      promoted.push({ threadId: id, title, firstUserMessage });
      assert.equal(metadata.cwd, "/Users/me/project");
      assert.equal(metadata.model, "gpt-5.5");
      assert.equal(metadata.reasoningEffort, "high");
      assert.equal(metadata.sandboxPolicy, "workspace-write");
      assert.equal(metadata.approvalMode, "on-request");
      desktopChats = [{
        id: `codex:${id}`,
        repo: "/Users/me/project",
        title,
        projectName: "project",
        status: "idle",
        startedAt: "2026-04-28T13:00:00.000Z",
        updatedAt: "2026-04-28T13:00:00.000Z",
        transcript: []
      }];
    },
    waitForCodexDesktopThreadSettled: async () => {},
    openCodexDesktopThread: async (id) => {
      opened.push(id);
    },
    startCodexDesktopTurn: async () => {},
    interruptCodexDesktopTurn: async () => {}
  });

  const chat = await manager.startChat({
    prompt: "Phone-created Codex chat",
    projectId: "/Users/me/project",
    projectPath: "/Users/me/project",
    workMode: "local",
    branch: "main",
    accessPreset: "on_request",
    model: "gpt-5.5",
    reasoningEffort: "high"
  });

  await new Promise((resolve) => setTimeout(resolve, 2_100));

  assert.equal(chat.id, `codex:${threadId}`);
  assert.equal(chat.title, "Phone-created Codex chat");
  assert.deepEqual(promoted, [
    { threadId, title: "Phone-created Codex chat", firstUserMessage: "Phone-created Codex chat" },
    { threadId, title: "Phone-created Codex chat", firstUserMessage: "Phone-created Codex chat" }
  ]);
  assert.deepEqual(opened, [threadId]);
  assert.ok(messages.some((message) => (message as { type?: string }).type === "chat_started"));
  assert.ok(messages.some((message) => {
    const serverMessage = message as { type?: string; chats?: Array<{ id: string }> };
    return serverMessage.type === "chat_list" && serverMessage.chats?.some((item) => item.id === `codex:${threadId}`);
  }));
});

test("continued Codex chats resume through the local Codex CLI", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  const messages: unknown[] = [];
  const promoted: Array<{ threadId: string; title: string; firstUserMessage: string }> = [];
  const stdout = new EventEmitter();
  const stderr = new EventEmitter();
  const child = new EventEmitter() as EventEmitter & { stdout: EventEmitter; stderr: EventEmitter };
  child.stdout = stdout;
  child.stderr = stderr;
  const desktopChat = {
    id: `codex:${threadId}`,
    repo: "/Users/me/project",
    title: "Say hello",
    projectName: "project",
    status: "idle" as const,
    startedAt: "2026-04-28T13:00:00.000Z",
    updatedAt: "2026-04-28T13:01:00.000Z",
    transcript: [
      "User:\nSay hello  \n\n",
      "Codex:\nHello.  \n\n"
    ]
  };

  const manager = new ChatManager((message) => messages.push(JSON.parse(JSON.stringify(message))), {
    listCodexChats: async () => [desktopChat],
    prepareChatWorkspace: async () => "/Users/me/project",
    startAgent: (repo, prompt, resumeSessionId) => {
      assert.equal(repo, "/Users/me/project");
      assert.equal(prompt, "Again");
      assert.equal(resumeSessionId, threadId);
      process.nextTick(() => {
        stdout.emit("data", Buffer.from(JSON.stringify({ type: "item.completed", item: { type: "agent_message", text: "Again hello." } })));
        child.emit("exit", 0);
      });
      return {
        child,
        acceptsInput: false,
        send() {},
        stop() {}
      } as never;
    },
    promoteCodexThreadToDesktop: async (id, title, firstUserMessage, metadata) => {
      promoted.push({ threadId: id, title, firstUserMessage });
      assert.equal(metadata.cwd, "/Users/me/project");
    },
    waitForCodexDesktopThreadSettled: async () => {},
    openCodexDesktopThread: async () => {},
    startCodexDesktopTurn: async () => {
      throw new Error("Desktop IPC should not be used for continued chats.");
    },
    interruptCodexDesktopTurn: async () => {}
  });

  const chat = await manager.continue(`codex:${threadId}`, "Again");
  await new Promise((resolve) => setImmediate(resolve));
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(chat.acceptsInput, false);
  assert.ok(chat.transcript?.some((entry) => entry.includes("Again")));
  assert.ok(messages.some((message) => {
    const started = message as { type?: string; chat?: { status?: string } };
    return started.type === "chat_started" && started.chat?.status === "running";
  }));
  assert.deepEqual(promoted, [
    { threadId, title: "Say hello", firstUserMessage: "Say hello" }
  ]);
  assert.ok(messages.some((message) => {
    const event = message as { type?: string; event?: { kind?: string; text?: string } };
    return event.type === "chat_event" &&
      event.event?.kind === "output" &&
      event.event.text?.includes("Again hello.");
  }));
  assert.ok(messages.some((message) => {
    const event = message as { type?: string; event?: { kind?: string } };
    return event.type === "chat_event" && event.event?.kind === "chat_completed";
  }));
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
