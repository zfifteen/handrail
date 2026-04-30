import test from "node:test";
import assert from "node:assert/strict";
import { extractStatus, parseDesktopPinnedThreadIds } from "../src/codexSessions.js";
import { codexDesktopFollowerTurnStartParams, codexDesktopIpcRequest, codexDesktopIpcRequestVersion, codexDesktopThreadStartParams, codexDesktopThreadUrl, encodeCodexDesktopIpcFrame } from "../src/codexDesktopIpc.js";
import { discoverProjects } from "../src/newChatOptions.js";
import { ChatManager } from "../src/chats.js";

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

test("builds Codex Desktop IPC follower requests", () => {
  const request = codexDesktopIpcRequest(
    "thread-follower-start-turn",
    codexDesktopFollowerTurnStartParams({
      threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
      cwd: "/Users/me/project",
      prompt: "Continue from phone"
    }),
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

test("builds Codex Desktop app-server thread-start params", () => {
  assert.deepEqual(codexDesktopThreadStartParams({
    cwd: "/Users/me/My Project",
    prompt: "Reply exactly HANDRAIL_OK",
    model: "gpt-5.5",
    reasoningEffort: "high",
    accessPreset: "on_request"
  }), {
    model: "gpt-5.5",
    modelProvider: null,
    cwd: "/Users/me/My Project",
    approvalPolicy: "on-request",
    sandbox: "workspace-write",
    config: { model_reasoning_effort: "high" },
    personality: null,
    ephemeral: false,
    experimentalRawEvents: false,
    dynamicTools: null,
    persistExtendedHistory: false,
    serviceTier: null
  });
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

test("new chat creation starts a Desktop-owned conversation", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  const messages: unknown[] = [];
  let desktopChats = [] as Awaited<ReturnType<ChatManager["list"]>>;

  const manager = new ChatManager((message) => messages.push(JSON.parse(JSON.stringify(message))), {
    listCodexChats: async () => desktopChats,
    prepareChatWorkspace: async (options) => {
      assert.equal(options.projectPath, "/Users/me/project");
      assert.equal(options.branch, "main");
      assert.equal(options.workMode, "local");
      return "/Users/me/project";
    },
    startCodexDesktopConversation: async (input) => {
      assert.deepEqual(input, {
        cwd: "/Users/me/project",
        prompt: "Phone-created Desktop chat",
        model: "gpt-5.5",
        reasoningEffort: "high",
        accessPreset: "on_request"
      });
      desktopChats = [{
        id: `codex:${threadId}`,
        repo: "/Users/me/project",
        title: "Phone-created Desktop chat",
        projectName: "project",
        status: "idle",
        startedAt: "2026-04-28T13:00:00.000Z",
        updatedAt: "2026-04-28T13:00:00.000Z",
        transcript: []
      }];
      return threadId;
    },
    startCodexDesktopTurn: async () => {},
    interruptCodexDesktopTurn: async () => {}
  });

  const chat = await manager.startChat({
    prompt: "Phone-created Desktop chat",
    projectId: "/Users/me/project",
    projectPath: "/Users/me/project",
    workMode: "local",
    branch: "main",
    accessPreset: "on_request",
    model: "gpt-5.5",
    reasoningEffort: "high"
  });

  assert.equal(chat.id, `codex:${threadId}`);
  assert.equal(chat.title, "Phone-created Desktop chat");
  assert.ok(messages.some((message) => (message as { type?: string }).type === "chat_started"));
  assert.ok(messages.some((message) => {
    const serverMessage = message as { type?: string; chats?: Array<{ id: string }> };
    return serverMessage.type === "chat_list" && serverMessage.chats?.some((item) => item.id === `codex:${threadId}`);
  }));
});

test("new chat creation fails instead of broadcasting an orphan when Desktop does not expose the chat", async () => {
  const messages: unknown[] = [];
  const manager = new ChatManager((message) => messages.push(message), {
    listCodexChats: async () => [],
    prepareChatWorkspace: async () => "/Users/me/project",
    startCodexDesktopConversation: async () => "019dc424-e857-76e0-8229-589ecf107eb4",
    startCodexDesktopTurn: async () => {},
    interruptCodexDesktopTurn: async () => {}
  });

  await assert.rejects(
    () => manager.startChat({
      prompt: "Phone-created Desktop chat",
      projectId: "/Users/me/project",
      projectPath: "/Users/me/project",
      workMode: "local",
      branch: "main",
      accessPreset: "on_request",
      model: "gpt-5.5",
      reasoningEffort: "high"
    }),
    /Codex Desktop did not expose chat codex:019dc424-e857-76e0-8229-589ecf107eb4/
  );
  assert.equal(messages.length, 0);
});

test("projectless new chat provides a Desktop projectless workspace", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  let desktopChats = [] as Awaited<ReturnType<ChatManager["list"]>>;
  const manager = new ChatManager(() => {}, {
    listCodexChats: async () => desktopChats,
    prepareChatWorkspace: async (options) => {
      assert.equal(options.projectPath, null);
      return "/Users/me/Documents/Codex";
    },
    startCodexDesktopConversation: async (input) => {
      assert.deepEqual(input, {
        cwd: "/Users/me/Documents/Codex",
        prompt: "Projectless prompt",
        model: "gpt-5.5",
        reasoningEffort: "high",
        accessPreset: "on_request"
      });
      desktopChats = [{
        id: `codex:${threadId}`,
        repo: "/Users/me/Documents/Codex",
        title: "Projectless prompt",
        projectName: "Codex",
        status: "idle",
        startedAt: "2026-04-28T13:00:00.000Z",
        updatedAt: "2026-04-28T13:00:00.000Z",
        transcript: []
      }];
      return threadId;
    },
    startCodexDesktopTurn: async () => {},
    interruptCodexDesktopTurn: async () => {}
  });

  await manager.startChat({
    prompt: "Projectless prompt",
    projectId: "no-project",
    projectPath: null,
    workMode: "local",
    branch: "",
    accessPreset: "on_request",
    model: "gpt-5.5",
    reasoningEffort: "high"
  });
});

test("continued Codex chats route through Codex Desktop IPC", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  const messages: unknown[] = [];
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
    startCodexDesktopConversation: async () => {
      throw new Error("New-conversation route should not be used for continued chats.");
    },
    startCodexDesktopTurn: async (input) => {
      assert.deepEqual(input, {
        threadId,
        cwd: "/Users/me/project",
        prompt: "Again"
      });
    },
    interruptCodexDesktopTurn: async () => {}
  });

  const chat = await manager.continue(`codex:${threadId}`, "Again");

  assert.equal(chat.acceptsInput, false);
  assert.ok(chat.transcript?.some((entry) => entry.includes("Again")));
  assert.ok(messages.some((message) => {
    const started = message as { type?: string; chat?: { status?: string } };
    return started.type === "chat_started" && started.chat?.status === "running";
  }));
  assert.ok(messages.some((message) => {
    const event = message as { type?: string; event?: { kind?: string; text?: string } };
    return event.type === "chat_event" &&
      event.event?.kind === "input_sent" &&
      event.event.text === "Again";
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

test("reads Codex Desktop status from the latest rollout event", () => {
  assert.equal(extractStatus([
    JSON.stringify({ type: "event_msg", payload: { type: "task_started" } })
  ]), "running");
  assert.equal(extractStatus([
    JSON.stringify({ type: "event_msg", payload: { type: "task_started" } }),
    JSON.stringify({ type: "event_msg", payload: { type: "task_complete" } })
  ]), "completed");
  assert.equal(extractStatus([
    JSON.stringify({ type: "event_msg", payload: { type: "task_complete" } }),
    JSON.stringify({ type: "event_msg", payload: { type: "task_started" } })
  ]), "running");
});
