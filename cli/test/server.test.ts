import test from "node:test";
import assert from "node:assert/strict";
import WebSocket from "ws";
import { once } from "node:events";
import { createHandrailServer } from "../src/server.js";
import type { ChatRecord, HandrailState, NewChatOptions, ServerMessage, StartChatOptions } from "../src/types.js";

const state: HandrailState = {
  protocolVersion: 1,
  port: 0,
  machineName: "Test Mac",
  defaultRepo: "/Users/me/project",
  pairingToken: "test-token"
};

const options: NewChatOptions = {
  projects: [
    { id: "no-project", name: "No project", path: null },
    { id: "/Users/me/project", name: "project", path: "/Users/me/project" }
  ],
  defaultProjectId: "/Users/me/project",
  branches: [{ name: "main", isCurrent: true }],
  defaultBranch: "main",
  workModes: ["local", "worktree"],
  accessPresets: ["full_access", "on_request", "read_only"],
  defaultAccessPreset: "on_request",
  models: ["gpt-5.5"],
  defaultModel: "gpt-5.5",
  reasoningEfforts: ["low", "medium", "high", "xhigh"],
  defaultReasoningEffort: "high"
};

test("WebSocket server pairs, refreshes chats, stops chats, and reports command errors", async () => {
  const chat: ChatRecord = {
    id: "codex:thread-1",
    repo: "/Users/me/project",
    title: "Desktop chat",
    projectName: "project",
    status: "idle",
    startedAt: "2026-04-29T00:00:00.000Z",
    updatedAt: "2026-04-29T00:01:00.000Z"
  };
  let stoppedChatId = "";

  const server = await createHandrailServer({
    state,
    port: 0,
    getOptions: async () => options,
    chats: {
      list: async () => [chat],
      startChat: async (_options: StartChatOptions) => chat,
      continue: async () => {
        throw new Error("No Codex chat with id codex:missing.");
      },
      sendInput() {
        throw new Error("Direct input is disabled.");
      },
      approve() {
        throw new Error("Approvals are disabled.");
      },
      deny() {
        throw new Error("Approvals are disabled.");
      },
      async stop(chatId: string) {
        stoppedChatId = chatId;
      }
    }
  });

  try {
    const ws = new WebSocket(`ws://127.0.0.1:${server.port}`);
    await once(ws, "open");
    const messages = new MessageInbox(ws);
    ws.send(JSON.stringify({ type: "hello", token: state.pairingToken }));

    assert.deepEqual(await messages.next(), {
      type: "machine_status",
      machineName: "Test Mac",
      online: true,
      defaultRepo: "/Users/me/project"
    } satisfies ServerMessage);

    const newChatOptions = await messages.next();
    assert.equal(newChatOptions.type, "new_chat_options");
    assert.equal(newChatOptions.options.defaultProjectId, "/Users/me/project");

    const initialList = await messages.next();
    assert.equal(initialList.type, "chat_list");
    assert.deepEqual(initialList.chats.map((item) => item.title), ["Desktop chat"]);

    ws.send(JSON.stringify({ type: "hello", token: state.pairingToken }));
    assert.equal((await messages.next()).type, "new_chat_options");
    assert.equal((await messages.next()).type, "chat_list");

    ws.send(JSON.stringify({ type: "stop_chat", chatId: chat.id }));
    assert.deepEqual(await messages.next(), {
      type: "command_result",
      ok: true,
      message: "Chat stop requested."
    } satisfies ServerMessage);
    assert.equal(stoppedChatId, chat.id);

    ws.send(JSON.stringify({ type: "continue_chat", chatId: "codex:missing", prompt: "Hello" }));
    assert.deepEqual(await messages.next(), {
      type: "error",
      message: "No Codex chat with id codex:missing."
    } satisfies ServerMessage);

    const close = once(ws, "close");
    ws.close();
    await close;
  } finally {
    await server.close();
  }
});

test("WebSocket server accepts and persists push token registration", async () => {
  let savedState: HandrailState | undefined;
  const server = await createHandrailServer({
    state: { ...state },
    port: 0,
    getOptions: async () => options,
    persistState: async (nextState) => {
      savedState = JSON.parse(JSON.stringify(nextState)) as HandrailState;
    },
    chats: {
      list: async () => [],
      startChat: async () => {
        throw new Error("unused");
      },
      continue: async () => {
        throw new Error("unused");
      },
      sendInput() {},
      approve() {
        throw new Error("unused");
      },
      deny() {
        throw new Error("unused");
      },
      async stop() {}
    }
  });

  try {
    const ws = new WebSocket(`ws://127.0.0.1:${server.port}`);
    await once(ws, "open");
    const messages = new MessageInbox(ws);
    ws.send(JSON.stringify({ type: "hello", token: state.pairingToken }));
    assert.equal((await messages.next()).type, "machine_status");
    assert.equal((await messages.next()).type, "new_chat_options");
    assert.equal((await messages.next()).type, "chat_list");

    ws.send(JSON.stringify({
      type: "register_push_token",
      deviceToken: "abcdef",
      environment: "sandbox",
      deviceName: "Test iPhone"
    }));

    await waitFor(() => savedState !== undefined);
    assert.equal(savedState?.pushDevice?.deviceToken, "abcdef");
    assert.equal(savedState?.pushDevice?.environment, "sandbox");
    assert.equal(savedState?.pushDevice?.deviceName, "Test iPhone");

    const close = once(ws, "close");
    ws.close();
    await close;
  } finally {
    await server.close();
  }
});

class MessageInbox {
  private readonly queue: ServerMessage[] = [];
  private readonly waiters: Array<(message: ServerMessage) => void> = [];

  constructor(socket: WebSocket) {
    socket.on("message", (data) => {
      const message = JSON.parse(String(data)) as ServerMessage;
      const waiter = this.waiters.shift();
      if (waiter) {
        waiter(message);
        return;
      }
      this.queue.push(message);
    });
  }

  next(): Promise<ServerMessage> {
    const message = this.queue.shift();
    if (message) {
      return Promise.resolve(message);
    }
    return new Promise((resolve) => this.waiters.push(resolve));
  }
}

async function waitFor(predicate: () => boolean): Promise<void> {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (predicate()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error("Timed out waiting for condition.");
}
