import test from "node:test";
import assert from "node:assert/strict";
import { join } from "node:path";
import { extractStatus, parseDesktopPinnedThreadIds } from "../src/codexSessions.js";
import { codexDesktopAppServerTurnStartParams, codexDesktopApprovalRequestFromServerRequest, codexDesktopFollowerTurnStartParams, codexDesktopIpcRequest, codexDesktopIpcRequestVersion, codexDesktopIpcSocketPath, codexDesktopLiveEventFromNotification, codexDesktopThreadStartParams, codexDesktopThreadUrl, encodeCodexDesktopIpcFrame, startCodexDesktopConversationOnAppServer } from "../src/codexDesktopIpc.js";
import { discoverProjectsFromPaths } from "../src/newChatOptions.js";
import { ChatManager } from "../src/chats.js";
import type { GrokApprovalRequest } from "../src/grokBuildAcp.js";

test("discovers New Chat projects from Grok session paths and default root", () => {
  const projects = discoverProjectsFromPaths([
    "/Users/me/IdeaProjects",
    "/Users/me/project",
    "/Users/me/project"
  ]);

  assert.deepEqual(projects, [
    { id: "no-project", name: "No project", path: null },
    { id: "/Users/me/IdeaProjects", name: "IdeaProjects", path: "/Users/me/IdeaProjects" },
    { id: "/Users/me/project", name: "project", path: "/Users/me/project" }
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

test("builds Codex Desktop app-server turn-start params", () => {
  assert.deepEqual(codexDesktopAppServerTurnStartParams({
    threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
    cwd: "/Users/me/project",
    prompt: "Start from phone"
  }), {
    threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
    input: [{ type: "text", text: "Start from phone", text_elements: [] }],
    cwd: "/Users/me/project"
  });
});

test("new Desktop conversations keep thread creation and first turn on one app-server connection", async () => {
  const calls: Array<{ method: string; params: unknown }> = [];
  let approvalHandlerWasSet = false;
  let liveEventHandlerWasSet = false;
  const client = {
    setApprovalRequestHandler() {
      approvalHandlerWasSet = true;
    },
    setLiveEventHandler() {
      liveEventHandlerWasSet = true;
    },
    async request(method: string, params: unknown): Promise<unknown> {
      calls.push({ method, params });
      if (method === "thread/start") {
        return { thread: { id: "019dc424-e857-76e0-8229-589ecf107eb4" } };
      }
      if (method === "turn/start") {
        return { turn: { id: "turn-1" } };
      }
      throw new Error(`Unexpected app-server method ${method}.`);
    }
  };

  const threadId = await startCodexDesktopConversationOnAppServer(client, {
    cwd: "/Users/me/project",
    prompt: "Start from phone",
    model: "gpt-5.5",
    reasoningEffort: "high",
    accessPreset: "on_request"
  }, () => {}, () => {});

  assert.equal(threadId, "019dc424-e857-76e0-8229-589ecf107eb4");
  assert.equal(approvalHandlerWasSet, true);
  assert.equal(liveEventHandlerWasSet, true);
  assert.deepEqual(calls.map((call) => call.method), ["thread/start", "turn/start"]);
  assert.deepEqual(calls[1].params, {
    threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
    input: [{ type: "text", text: "Start from phone", text_elements: [] }],
    cwd: "/Users/me/project"
  });
});

test("converts Codex Desktop app-server notifications into live events", () => {
  assert.deepEqual(codexDesktopLiveEventFromNotification("turn/started", {
    threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
    turn: { id: "turn-1", status: "inProgress" }
  }), {
    threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
    kind: "turn_started",
    text: "Codex Desktop turn started."
  });

  assert.deepEqual(codexDesktopLiveEventFromNotification("turn/completed", {
    threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
    turn: { id: "turn-1", status: "failed", error: { message: "Tests failed." } }
  }), {
    threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
    kind: "turn_failed",
    text: "Tests failed."
  });

  assert.deepEqual(codexDesktopLiveEventFromNotification("item/agentMessage/delta", {
    threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
    turnId: "turn-1",
    itemId: "item-1",
    delta: "Hello"
  }), {
    threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
    kind: "output",
    text: "Hello"
  });
});

test("converts Codex Desktop command approval requests into Handrail approval ids", async () => {
  let decision: string | null = null;
  const approval = codexDesktopApprovalRequestFromServerRequest(
    "server-request-1",
    "item/commandExecution/requestApproval",
    {
      threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
      itemId: "item-1",
      turnId: "turn-1",
      command: "npm test",
      reason: null
    },
    async (nextDecision) => {
      decision = nextDecision;
    }
  );

  assert.deepEqual(approval && {
    threadId: approval.threadId,
    approvalId: approval.approvalId,
    title: approval.title,
    summary: approval.summary,
    files: approval.files,
    diff: approval.diff
  }, {
    threadId: "019dc424-e857-76e0-8229-589ecf107eb4",
    approvalId: "server-request-1",
    title: "Command approval required",
    summary: "npm test",
    files: [],
    diff: ""
  });
  await approval?.respond("accept");
  assert.equal(decision, "accept");
});

test("builds Codex Desktop thread deeplinks", () => {
  assert.equal(
    codexDesktopThreadUrl("019dc424-e857-76e0-8229-589ecf107eb4"),
    "codex://threads/019dc424-e857-76e0-8229-589ecf107eb4"
  );
});

test("uses the Darwin user temp dir for Codex Desktop IPC", () => {
  const previousTmpdir = process.env.TMPDIR;
  process.env.TMPDIR = "/var/folders/test/T/";
  try {
    const socketName = typeof process.getuid === "function" ? `ipc-${process.getuid()}.sock` : "ipc.sock";
    assert.equal(codexDesktopIpcSocketPath(), join("/var/folders/test/T", "codex-ipc", socketName));
  } finally {
    if (previousTmpdir === undefined) {
      delete process.env.TMPDIR;
    } else {
      process.env.TMPDIR = previousTmpdir;
    }
  }
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

test("chat manager refuses non-Grok chat ids", async () => {
  const manager = new ChatManager(() => {});
  await assert.rejects(
    () => manager.stop("local-process-id"),
    /No Grok chat with id local-process-id/
  );
});

test("chat manager rejects unknown approval ids", async () => {
  const manager = new ChatManager(() => {});

  await assert.rejects(
    () => manager.approve("grok:thread-1", "approval-1"),
    /No pending approval approval-1 for Grok chat grok:thread-1/
  );
  await assert.rejects(
    () => manager.deny("grok:thread-1", "approval-1", "No"),
    /No pending approval approval-1 for Grok chat grok:thread-1/
  );
});

test("chat manager routes Codex Desktop approval decisions by server request id", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  const messages: unknown[] = [];
  let desktopChats = [] as Awaited<ReturnType<ChatManager["list"]>>;
  let approvalDecision: string | null = null;

  const manager = new ChatManager((message) => messages.push(JSON.parse(JSON.stringify(message))), {
    listGrokChats: async () => desktopChats,
    readGrokChatDetail: async (chatId) => desktopChats.find((chat) => chat.id === chatId) ?? null,
    prepareChatWorkspace: async () => "/Users/me/project",
    startGrokConversation: async (_input, onApprovalRequest) => {
      desktopChats = [{
        id: `grok:${threadId}`,
        repo: "/Users/me/project",
        title: "Approval route test",
        projectName: "project",
        status: "running",
        startedAt: "2026-04-28T13:00:00.000Z",
        updatedAt: "2026-04-28T13:00:00.000Z",
        transcript: []
      }];
      onApprovalRequest?.({
        sessionId: threadId,
        approvalId: "server-request-1",
        title: "Command approval required",
        summary: "npm test",
        files: [],
        diff: "",
        respond: async (decision) => {
          approvalDecision = decision;
        }
      });
      return threadId;
    },
    continueGrokTurn: async () => {},
    interruptGrokTurn: async () => {}
  });

  await manager.startChat({
    prompt: "Approval route test",
    projectId: "/Users/me/project",
    projectPath: "/Users/me/project",
    workMode: "local",
    branch: "main",
    accessPreset: "on_request",
    model: "gpt-5.5",
    reasoningEffort: "high"
  });

  assert.ok(messages.some((message) => {
    const approval = message as { type?: string; approvalId?: string; chatId?: string };
    return approval.type === "approval_required" &&
      approval.approvalId === "server-request-1" &&
      approval.chatId === `grok:${threadId}`;
  }));
  assert.equal((await manager.list())[0]?.status, "waiting_for_approval");

  const approval = await manager.approve(`grok:${threadId}`, "server-request-1");

  assert.equal(approval.summary, "npm test");
  assert.equal(approvalDecision, "accept");
  assert.equal((await manager.list())[0]?.status, "running");
  assert.ok(messages.some((message) => {
    const event = message as { type?: string; event?: { kind?: string } };
    return event.type === "chat_event" && event.event?.kind === "approval_approved";
  }));
});

test("chat manager scopes duplicate approval ids by chat id", async () => {
  const threadIds = [
    "019dc424-e857-76e0-8229-589ecf107eb4",
    "019dc424-e857-76e0-8229-589ecf107eb5"
  ];
  const messages: unknown[] = [];
  const approvalHandlers = new Map<string, (approval: GrokApprovalRequest) => void>();
  const decisions = new Map<string, string>();
  let startIndex = 0;
  let desktopChats = [] as Awaited<ReturnType<ChatManager["list"]>>;

  const manager = new ChatManager((message) => messages.push(JSON.parse(JSON.stringify(message))), {
    listGrokChats: async () => desktopChats,
    readGrokChatDetail: async (chatId) => desktopChats.find((chat) => chat.id === chatId) ?? null,
    prepareChatWorkspace: async () => "/Users/me/project",
    startGrokConversation: async (_input, onApprovalRequest) => {
      assert.ok(onApprovalRequest);
      const threadId = threadIds[startIndex];
      startIndex += 1;
      approvalHandlers.set(threadId, onApprovalRequest);
      desktopChats = [...desktopChats, {
        id: `grok:${threadId}`,
        repo: "/Users/me/project",
        title: `Approval scope test ${startIndex}`,
        projectName: "project",
        status: "running" as const,
        startedAt: "2026-04-28T13:00:00.000Z",
        updatedAt: `2026-04-28T13:00:0${startIndex}.000Z`,
        transcript: []
      }];
      return threadId;
    },
    continueGrokTurn: async () => {},
    interruptGrokTurn: async () => {}
  });

  for (const threadId of threadIds) {
    await manager.startChat({
      prompt: `Approval scope test ${threadId}`,
      projectId: "/Users/me/project",
      projectPath: "/Users/me/project",
      workMode: "local",
      branch: "main",
      accessPreset: "on_request",
      model: "gpt-5.5",
      reasoningEffort: "high"
    });
    approvalHandlers.get(threadId)?.({
      sessionId: threadId,
      approvalId: "server-request-1",
      title: "Command approval required",
      summary: "npm test",
      files: [],
      diff: "",
      respond: async (decision) => {
        decisions.set(threadId, decision);
      }
    });
    await new Promise((resolve) => setImmediate(resolve));
  }

  await manager.approve(`grok:${threadIds[0]}`, "server-request-1");

  assert.equal(decisions.get(threadIds[0]), "accept");
  assert.equal(decisions.has(threadIds[1]), false);
  assert.equal((await manager.list()).find((chat) => chat.id === `grok:${threadIds[0]}`)?.status, "running");
  assert.equal((await manager.list()).find((chat) => chat.id === `grok:${threadIds[1]}`)?.status, "waiting_for_approval");
});

test("chat manager broadcasts chat list when approval state changes", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  const messages: unknown[] = [];
  let approvalHandler = (_approval: GrokApprovalRequest): void => {
    throw new Error("Approval handler was not installed.");
  };
  const desktopChats = [{
    id: `grok:${threadId}`,
    repo: "/Users/me/project",
    title: "Approval broadcast test",
    projectName: "project",
    status: "running" as const,
    startedAt: "2026-04-28T13:00:00.000Z",
    updatedAt: "2026-04-28T13:00:00.000Z",
    transcript: []
  }];

  const manager = new ChatManager((message) => messages.push(JSON.parse(JSON.stringify(message))), {
    listGrokChats: async () => desktopChats,
    readGrokChatDetail: async (chatId) => desktopChats.find((chat) => chat.id === chatId) ?? null,
    prepareChatWorkspace: async () => "/Users/me/project",
    startGrokConversation: async (_input, onApprovalRequest) => {
      assert.ok(onApprovalRequest);
      approvalHandler = onApprovalRequest;
      return threadId;
    },
    continueGrokTurn: async () => {},
    interruptGrokTurn: async () => {}
  });

  await manager.startChat({
    prompt: "Approval broadcast test",
    projectId: "/Users/me/project",
    projectPath: "/Users/me/project",
    workMode: "local",
    branch: "main",
    accessPreset: "on_request",
    model: "gpt-5.5",
    reasoningEffort: "high"
  });
  messages.length = 0;

  approvalHandler({
    sessionId: threadId,
    approvalId: "server-request-1",
    title: "Command approval required",
    summary: "npm test",
    files: [],
    diff: "",
    respond: async () => {}
  });
  await new Promise((resolve) => setImmediate(resolve));

  assert.ok(messages.some((message) => {
    const chatList = message as { type?: string; chats?: Array<{ id?: string; status?: string }> };
    return chatList.type === "chat_list" &&
      chatList.chats?.some((chat) => chat.id === `grok:${threadId}` && chat.status === "waiting_for_approval");
  }));
});

test("Grok approval requests wait for session visibility before mobile broadcast", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  const messages: unknown[] = [];
  let resolveApprovalChatList = (): void => {};
  const approvalChatListBroadcasted = new Promise<void>((resolve) => {
    resolveApprovalChatList = resolve;
  });
  let desktopVisible = false;
  let approvalHandler = (_approval: GrokApprovalRequest): void => {
    throw new Error("Approval handler was not installed.");
  };
  const desktopChat = {
    id: `grok:${threadId}`,
    repo: "/Users/me/project",
    title: "Approval visibility test",
    projectName: "project",
    status: "running" as const,
    startedAt: "2026-04-28T13:00:00.000Z",
    updatedAt: "2026-04-28T13:00:00.000Z",
    transcript: []
  };

  const manager = new ChatManager((message) => {
    const snapshot = JSON.parse(JSON.stringify(message)) as { type?: string; chats?: Array<{ id?: string; status?: string }> };
    messages.push(snapshot);
    if (
      snapshot.type === "chat_list" &&
      snapshot.chats?.some((chat) => chat.id === `grok:${threadId}` && chat.status === "waiting_for_approval")
    ) {
      resolveApprovalChatList();
    }
  }, {
    listGrokChats: async () => desktopVisible ? [desktopChat] : [],
    readGrokChatDetail: async (chatId) => chatId === desktopChat.id ? desktopChat : null,
    prepareChatWorkspace: async () => "/Users/me/project",
    startGrokConversation: async (_input, onApprovalRequest) => {
      assert.ok(onApprovalRequest);
      approvalHandler = onApprovalRequest;
      return threadId;
    },
    continueGrokTurn: async () => {},
    interruptGrokTurn: async () => {}
  });

  const started = manager.startChat({
    prompt: "Approval visibility test",
    projectId: "/Users/me/project",
    projectPath: "/Users/me/project",
    workMode: "local",
    branch: "main",
    accessPreset: "on_request",
    model: "gpt-5.5",
    reasoningEffort: "high"
  });
  await new Promise((resolve) => setImmediate(resolve));

  approvalHandler({
    sessionId: threadId,
    approvalId: "server-request-1",
    title: "Command approval required",
    summary: "npm test",
    files: [],
    diff: "",
    respond: async () => {}
  });
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(messages.length, 0);

  desktopVisible = true;
  await started;
  await approvalChatListBroadcasted;

  assert.ok(messages.some((message) => {
    const approval = message as { type?: string; approvalId?: string; chatId?: string };
    return approval.type === "approval_required" &&
      approval.approvalId === "server-request-1" &&
      approval.chatId === `grok:${threadId}`;
  }));
  assert.ok(messages.some((message) => {
    const chatList = message as { type?: string; chats?: Array<{ id?: string; status?: string }> };
    return chatList.type === "chat_list" &&
      chatList.chats?.some((chat) => chat.id === `grok:${threadId}` && chat.status === "waiting_for_approval");
  }));
});

test("chat manager broadcasts live app-server turn events for visible Desktop chats", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  const messages: unknown[] = [];
  let desktopChats = [{
    id: `grok:${threadId}`,
    repo: "/Users/me/project",
    title: "Live event route test",
    projectName: "project",
    status: "idle" as const,
    startedAt: "2026-04-28T13:00:00.000Z",
    updatedAt: "2026-04-28T13:00:00.000Z",
    transcript: []
  }];

  const manager = new ChatManager((message) => messages.push(JSON.parse(JSON.stringify(message))), {
    listGrokChats: async () => desktopChats,
    readGrokChatDetail: async (chatId) => desktopChats.find((chat) => chat.id === chatId) ?? null,
    prepareChatWorkspace: async () => "/Users/me/project",
    startGrokConversation: async (_input, _onApprovalRequest, onLiveEvent) => {
      onLiveEvent?.({ sessionId: threadId, kind: "turn_started", text: "Grok Build turn started." });
      onLiveEvent?.({ sessionId: threadId, kind: "output", text: "Hello from Grok." });
      onLiveEvent?.({ sessionId: threadId, kind: "turn_completed", text: "Grok Build turn completed." });
      return threadId;
    },
    continueGrokTurn: async () => {},
    interruptGrokTurn: async () => {}
  });

  await manager.startChat({
    prompt: "Live event route test",
    projectId: "/Users/me/project",
    projectPath: "/Users/me/project",
    workMode: "local",
    branch: "main",
    accessPreset: "on_request",
    model: "gpt-5.5",
    reasoningEffort: "high"
  });

  assert.ok(messages.some((message) => {
    const event = message as { type?: string; event?: { kind?: string; text?: string } };
    return event.type === "chat_event" && event.event?.kind === "output" && event.event.text === "Hello from Grok.";
  }));
  assert.ok(messages.some((message) => {
    const event = message as { type?: string; event?: { kind?: string; status?: string } };
    return event.type === "chat_event" && event.event?.kind === "chat_completed" && event.event.status === "completed";
  }));
  assert.equal((await manager.list())[0]?.status, "completed");
});

test("new chat creation starts a Desktop-owned conversation", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  const messages: unknown[] = [];
  let desktopChats = [] as Awaited<ReturnType<ChatManager["list"]>>;

  const manager = new ChatManager((message) => messages.push(JSON.parse(JSON.stringify(message))), {
    listGrokChats: async () => desktopChats,
    readGrokChatDetail: async (chatId) => desktopChats.find((chat) => chat.id === chatId) ?? null,
    prepareChatWorkspace: async (options) => {
      assert.equal(options.projectPath, "/Users/me/project");
      assert.equal(options.branch, "main");
      assert.equal(options.workMode, "local");
      return "/Users/me/project";
    },
    startGrokConversation: async (input) => {
      assert.deepEqual(input, {
        cwd: "/Users/me/project",
        prompt: "Phone-created Desktop chat",
        model: "gpt-5.5",
        reasoningEffort: "high",
        accessPreset: "on_request"
      });
      desktopChats = [{
        id: `grok:${threadId}`,
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
    continueGrokTurn: async () => {},
    interruptGrokTurn: async () => {}
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

  assert.equal(chat.id, `grok:${threadId}`);
  assert.equal(chat.title, "Phone-created Desktop chat");
  assert.ok(messages.some((message) => (message as { type?: string }).type === "chat_started"));
  assert.ok(messages.some((message) => {
    const serverMessage = message as { type?: string; chats?: Array<{ id: string }> };
    return serverMessage.type === "chat_list" && serverMessage.chats?.some((item) => item.id === `grok:${threadId}`);
  }));
});

test("new chat creation waits for Desktop visibility before broadcasting", async () => {
  const messages: unknown[] = [];
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  let listCalls = 0;
  const manager = new ChatManager((message) => messages.push(JSON.parse(JSON.stringify(message))), {
    listGrokChats: async () => {
      listCalls += 1;
      if (listCalls < 2) {
        return [];
      }
      return [{
        id: `grok:${threadId}`,
        repo: "/Users/me/project",
        title: "Phone-created Desktop chat",
        projectName: "project",
        status: "idle",
        startedAt: "2026-04-28T13:00:00.000Z",
        updatedAt: "2026-04-28T13:00:00.000Z",
        transcript: []
      }];
    },
    readGrokChatDetail: async () => null,
    prepareChatWorkspace: async () => "/Users/me/project",
    startGrokConversation: async () => threadId,
    continueGrokTurn: async () => {},
    interruptGrokTurn: async () => {}
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

  assert.equal(chat.id, `grok:${threadId}`);
  assert.equal(chat.status, "running");
  assert.equal(listCalls, 3);
  assert.ok(messages.some((message) => {
    const serverMessage = message as { type?: string; chats?: Array<{ id: string }> };
    return serverMessage.type === "chat_list" && serverMessage.chats?.[0]?.id === `grok:${threadId}`;
  }));
});

test("new chat creation fails instead of broadcasting an orphan when Desktop does not expose the chat", async () => {
  const messages: unknown[] = [];
  const manager = new ChatManager((message) => messages.push(message), {
    listGrokChats: async () => [],
    readGrokChatDetail: async () => null,
    prepareChatWorkspace: async () => "/Users/me/project",
    startGrokConversation: async () => "019dc424-e857-76e0-8229-589ecf107eb4",
    continueGrokTurn: async () => {},
    interruptGrokTurn: async () => {}
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
    /Grok Build did not expose chat grok:019dc424-e857-76e0-8229-589ecf107eb4/
  );
  assert.equal(messages.length, 0);
});

test("projectless new chat provides a Desktop projectless workspace", async () => {
  const threadId = "019dc424-e857-76e0-8229-589ecf107eb4";
  let desktopChats = [] as Awaited<ReturnType<ChatManager["list"]>>;
  const manager = new ChatManager(() => {}, {
    listGrokChats: async () => desktopChats,
    readGrokChatDetail: async (chatId) => desktopChats.find((chat) => chat.id === chatId) ?? null,
    prepareChatWorkspace: async (options) => {
      assert.equal(options.projectPath, null);
      return "/Users/me/Documents/Codex";
    },
    startGrokConversation: async (input) => {
      assert.deepEqual(input, {
        cwd: "/Users/me/Documents/Codex",
        prompt: "Projectless prompt",
        model: "gpt-5.5",
        reasoningEffort: "high",
        accessPreset: "on_request"
      });
      desktopChats = [{
        id: `grok:${threadId}`,
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
    continueGrokTurn: async () => {},
    interruptGrokTurn: async () => {}
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
    id: `grok:${threadId}`,
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
    listGrokChats: async () => [desktopChat],
    readGrokChatDetail: async (chatId) => chatId === desktopChat.id ? desktopChat : null,
    prepareChatWorkspace: async () => "/Users/me/project",
    startGrokConversation: async () => {
      throw new Error("New-conversation route should not be used for continued chats.");
    },
    continueGrokTurn: async (input) => {
      assert.deepEqual(input, {
        sessionId: threadId,
        cwd: "/Users/me/project",
        prompt: "Again"
      });
    },
    interruptGrokTurn: async () => {}
  });

  const chat = await manager.continue(`grok:${threadId}`, "Again");

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
