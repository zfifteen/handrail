#!/usr/bin/env node
/**
 * Phase 3 Grok Build end-to-end probe for the live Handrail WebSocket server.
 * Writes artifacts under test-artifacts/phase3-grok-e2e-<stamp>/.
 */
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { mkdtemp } from "node:fs/promises";
import WebSocket from "../../cli/node_modules/ws/wrapper.mjs";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const statePath = join(homedir(), ".handrail", "state.json");
const continuePrompt = "Handrail Phase 3 continue probe. Reply exactly HANDRAIL_PHASE3_CONTINUE_OK.";
const startPrompt = "Handrail Phase 3 start probe. Reply exactly HANDRAIL_PHASE3_START_OK.";

async function main() {
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const outDir = join(repoRoot, "test-artifacts", `phase3-grok-e2e-${stamp}`);
  await mkdir(outDir, { recursive: true });

  const state = JSON.parse(await readFile(statePath, "utf8"));
  if (!state.pairingToken || !state.port) {
    throw new Error(`Missing pairing token or port in ${statePath}`);
  }

  const socket = new ProbeSocket(`ws://127.0.0.1:${state.port}`, state.pairingToken, join(outDir, "messages.ndjson"));
  const summary = {
    ranAt: new Date().toISOString(),
    server: `ws://127.0.0.1:${state.port}`,
    branch: "revive/grok-build",
    checks: {},
    allPassed: false
  };

  try {
    await socket.connect();
    summary.checks.handshake = await checkHandshake(socket);
    summary.checks.chatList = await checkChatList(socket);
    summary.checks.chatDetail = await checkChatDetail(socket, summary.checks.chatList.sampleChatId);
    summary.checks.continueChat = await checkContinueChat(socket, summary.checks.chatList.idleChatId);
    summary.checks.startChat = await checkStartChat(socket, outDir);
    summary.checks.stopChat = await checkStopChat(socket, summary.checks.startChat.chatId);
    summary.allPassed = Object.values(summary.checks).every((check) => check.ok);
  } finally {
    await socket.close();
    await writeFile(join(outDir, "summary.json"), `${JSON.stringify(summary, null, 2)}\n`);
    console.log(JSON.stringify({ outDir, allPassed: summary.allPassed, checks: summary.checks }, null, 2));
    process.exit(summary.allPassed ? 0 : 1);
  }
}

async function checkHandshake(socket) {
  const machine = await socket.waitFor((message) => message.type === "machine_status", 10_000);
  const options = await socket.waitFor((message) => message.type === "new_chat_options", 10_000);
  const chats = await socket.waitFor((message) => message.type === "chat_list", 10_000);
  const automations = await socket.waitFor((message) => message.type === "automation_list", 10_000);

  const ok = Boolean(machine.online)
    && options.options.defaultModel.length > 0
    && Array.isArray(chats.chats)
    && Array.isArray(automations.automations)
    && automations.automations.length === 0;

  return {
    ok,
    machineName: machine.machineName,
    defaultModel: options.options.defaultModel,
    chatCount: chats.chats.length,
    automationCount: automations.automations.length
  };
}

async function checkChatList(socket) {
  socket.send({ type: "hello", token: socket.token });
  const list = await socket.waitFor((message) => message.type === "chat_list", 10_000);
  const chats = list.chats ?? [];
  const grokIds = chats.map((chat) => chat.id).filter((id) => id.startsWith("grok:"));
  const sorted = [...chats].sort(
    (left, right) => new Date(right.updatedAt ?? right.startedAt) - new Date(left.updatedAt ?? left.startedAt)
  );
  const orderMatches = chats.every((chat, index) => chat.id === sorted[index]?.id);
  const idleChat = chats.find((chat) => chat.status === "idle");
  const sampleChatId = chats[0]?.id ?? null;

  return {
    ok: chats.length > 0 && grokIds.length === chats.length && orderMatches && Boolean(sampleChatId),
    total: chats.length,
    grokIdCount: grokIds.length,
    orderMatches,
    sampleChatId,
    idleChatId: idleChat?.id ?? null
  };
}

async function checkChatDetail(socket, chatId) {
  if (!chatId) {
    return { ok: false, reason: "no chat id" };
  }
  socket.send({ type: "get_chat_detail", chatId });
  const detail = await socket.waitFor((message) => message.type === "chat_detail", 15_000);
  const transcript = detail.chat.transcript ?? [];
  const hasGrokBlocks = transcript.some((line) => line.startsWith("Grok:") || line.startsWith("User:"));

  return {
    ok: detail.chat.id === chatId && transcript.length > 0 && hasGrokBlocks,
    chatId: detail.chat.id,
    transcriptLines: transcript.length,
    hasGrokBlocks
  };
}

async function checkContinueChat(socket, chatId) {
  if (!chatId) {
    return { ok: false, reason: "no idle chat available", skipped: true };
  }
  socket.send({ type: "continue_chat", chatId, prompt: continuePrompt });
  const started = await socket.waitFor(
    (message) => message.type === "chat_started" || message.type === "error",
    180_000
  );
  if (started.type === "error") {
    return { ok: false, chatId, error: started.message };
  }
  return {
    ok: started.chat.id === chatId && started.chat.status === "running",
    chatId,
    status: started.chat.status
  };
}

async function checkStartChat(socket, outDir) {
  const workdir = await mkdtemp(join(tmpdir(), "handrail-phase3-start-"));
  socket.send({
    type: "start_chat",
    prompt: startPrompt,
    projectId: workdir,
    projectPath: workdir,
    workMode: "local",
    branch: "",
    accessPreset: "on_request",
    model: "grok-build",
    reasoningEffort: "high"
  });
  const started = await socket.waitFor(
    (message) => message.type === "chat_started" || message.type === "error",
    180_000
  );
  if (started.type === "error") {
    return { ok: false, workdir, error: started.message };
  }
  await writeFile(join(outDir, "started-chat.json"), `${JSON.stringify(started.chat, null, 2)}\n`);
  return {
    ok: started.chat.id.startsWith("grok:") && started.chat.status === "running",
    chatId: started.chat.id,
    workdir,
    title: started.chat.title
  };
}

async function checkStopChat(socket, chatId) {
  if (!chatId) {
    return { ok: false, reason: "no started chat", skipped: true };
  }
  socket.send({ type: "stop_chat", chatId });
  const result = await socket.waitFor(
    (message) => message.type === "command_result" || message.type === "error",
    30_000
  );
  if (result.type === "error") {
    return { ok: false, chatId, error: result.message };
  }
  return {
    ok: result.ok === true,
    chatId,
    message: result.message
  };
}

class ProbeSocket {
  constructor(url, token, logPath) {
    this.url = url;
    this.token = token;
    this.logPath = logPath;
    this.queue = [];
    this.waiters = [];
    this.ws = null;
  }

  async connect() {
    this.ws = new WebSocket(this.url);
    await new Promise((resolve, reject) => {
      this.ws.once("open", resolve);
      this.ws.once("error", reject);
    });
    this.ws.on("message", (data) => {
      const message = JSON.parse(String(data));
      void writeFile(this.logPath, `${JSON.stringify({ at: new Date().toISOString(), message })}\n`, { flag: "a" });
      const waiter = this.waiters.shift();
      if (waiter) {
        waiter(message);
      } else {
        this.queue.push(message);
      }
    });
    this.send({ type: "hello", token: this.token });
  }

  send(payload) {
    this.ws.send(JSON.stringify(payload));
  }

  waitFor(predicate, timeoutMs, label = "message") {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Timed out waiting for ${label}`)), timeoutMs);
      const tryMessage = (message) => {
        if (!predicate(message)) {
          this.waiters.push(tryMessage);
          return;
        }
        clearTimeout(timer);
        resolve(message);
      };
      const queued = this.queue.find(predicate);
      if (queued) {
        this.queue = this.queue.filter((message) => message !== queued);
        clearTimeout(timer);
        resolve(queued);
        return;
      }
      this.waiters.push(tryMessage);
    });
  }

  async close() {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.close();
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});