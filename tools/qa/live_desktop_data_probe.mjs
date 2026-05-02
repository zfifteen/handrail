#!/usr/bin/env node
import { execFile } from "node:child_process";
import { createWriteStream } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import WebSocket from "../../cli/node_modules/ws/wrapper.mjs";

const execFileAsync = promisify(execFile);
const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const cliRoot = join(repoRoot, "cli");
const statePath = join(homedir(), ".handrail", "state.json");
const reproRoot = "/private/tmp/handrail-live-data-repro";
const observeAfterStartMs = 20_000;
const observeAfterApprovalMs = 120_000;
const waitForStartMs = 120_000;

const startPrompt = [
  "Handrail live data repro start-chat case.",
  "Reply exactly HANDRAIL_LIVE_REPRO_START_OK and do not edit files."
].join("\n");

const approvalPrompt = [
  "Handrail live data repro approval case.",
  "Modify approval-target.txt in the current directory by appending this exact line:",
  "HANDRAIL_LIVE_REPRO_APPROVAL_OK",
  "Use the file editing tool. Do not merely describe the change."
].join("\n");

async function main() {
  const runStamp = timestampForPath(new Date());
  const outDir = join(repoRoot, "test-artifacts", `live-data-root-cause-${runStamp}`);
  await mkdir(outDir, { recursive: true });

  const state = await readJson(statePath);
  if (!state.pairingToken) {
    throw new Error(`No Handrail pairing token found in ${statePath}. Run handrail pair first.`);
  }
  if (!state.port) {
    throw new Error(`No Handrail port found in ${statePath}.`);
  }

  await prepareReproDirectory();
  await writeJson(join(outDir, "probe-config.json"), {
    createdAt: new Date().toISOString(),
    statePath,
    server: `ws://127.0.0.1:${state.port}`,
    machineName: state.machineName,
    defaultRepo: state.defaultRepo,
    reproRoot,
    observeAfterStartMs,
    observeAfterApprovalMs,
    waitForStartMs
  });

  const messagesPath = join(outDir, "server-messages.ndjson");
  const socket = new ProbeSocket(`ws://127.0.0.1:${state.port}`, state.pairingToken, messagesPath);
  await socket.connect();

  const summary = {
    outDir,
    baseline: {},
    startChat: {},
    approvalChat: {},
    conclusions: {}
  };

  socket.setPhase("baseline");
  await socket.waitFor((message) => message.type === "machine_status", 15_000, "machine_status");
  const baselineList = await socket.waitFor((message) => message.type === "chat_list", 15_000, "baseline chat_list");
  summary.baseline = summarizeChatList(baselineList);
  await snapshotCliChats(outDir, "baseline");
  await snapshotDesktopState(outDir, "baseline");

  socket.setPhase("start-chat");
  const startSentAt = new Date().toISOString();
  socket.send({
    type: "start_chat",
    prompt: startPrompt,
    projectId: reproRoot,
    projectPath: reproRoot,
    workMode: "local",
    branch: "",
    accessPreset: "on_request",
    model: "gpt-5.5",
    reasoningEffort: "high"
  });
  const startResult = await waitForChatStartOrError(socket, waitForStartMs, "start-chat result");
  summary.startChat = await observeStartedChat(socket, startResult, startSentAt, observeAfterStartMs);
  await snapshotCliChats(outDir, "after-start-chat");
  await snapshotDesktopState(outDir, "after-start-chat", summary.startChat.chatId);

  socket.setPhase("approval-repro");
  const approvalSentAt = new Date().toISOString();
  socket.send({
    type: "start_chat",
    prompt: approvalPrompt,
    projectId: reproRoot,
    projectPath: reproRoot,
    workMode: "local",
    branch: "",
    accessPreset: "read_only",
    model: "gpt-5.5",
    reasoningEffort: "high"
  });
  const approvalStartResult = await waitForChatStartOrError(socket, waitForStartMs, "approval start result");
  summary.approvalChat = await observeApprovalChat(socket, approvalStartResult, approvalSentAt, observeAfterApprovalMs);
  await snapshotCliChats(outDir, "after-approval-repro");
  await snapshotDesktopState(outDir, "after-approval-repro", summary.approvalChat.chatId);

  summary.conclusions = classify(summary);
  await writeJson(join(outDir, "summary.json"), summary);
  await socket.close();

  console.log(outDir);
}

class ProbeSocket {
  constructor(url, token, messagesPath) {
    this.url = url;
    this.token = token;
    this.phase = "connect";
    this.queue = [];
    this.waiters = [];
    this.stream = createWriteStream(messagesPath, { flags: "a" });
  }

  async connect() {
    this.ws = new WebSocket(this.url);
    await new Promise((resolveOpen, rejectOpen) => {
      this.ws.once("open", resolveOpen);
      this.ws.once("error", rejectOpen);
    });
    this.ws.on("message", (data) => this.record(data));
    this.ws.on("error", (error) => {
      this.stream.write(`${JSON.stringify({
        receivedAt: new Date().toISOString(),
        phase: this.phase,
        transportError: error.message
      })}\n`);
    });
    this.send({ type: "hello", token: this.token });
  }

  setPhase(phase) {
    this.phase = phase;
  }

  send(message) {
    this.ws.send(JSON.stringify(message));
  }

  record(data) {
    const receivedAt = new Date().toISOString();
    const message = JSON.parse(String(data));
    this.stream.write(`${JSON.stringify({ receivedAt, phase: this.phase, message })}\n`);
    const waiterIndex = this.waiters.findIndex((waiter) => waiter.predicate(message));
    if (waiterIndex >= 0) {
      const [waiter] = this.waiters.splice(waiterIndex, 1);
      clearTimeout(waiter.timer);
      waiter.resolve(message);
      return;
    }
    this.queue.push(message);
  }

  waitFor(predicate, timeoutMs, label) {
    const queuedIndex = this.queue.findIndex(predicate);
    if (queuedIndex >= 0) {
      const [message] = this.queue.splice(queuedIndex, 1);
      return Promise.resolve(message);
    }
    return new Promise((resolveWait, rejectWait) => {
      const timer = setTimeout(() => {
        const index = this.waiters.findIndex((waiter) => waiter.resolve === resolveWait);
        if (index >= 0) {
          this.waiters.splice(index, 1);
        }
        rejectWait(new Error(`Timed out waiting for ${label}.`));
      }, timeoutMs);
      this.waiters.push({ predicate, resolve: resolveWait, timer });
    });
  }

  drainMatching(predicate) {
    const matches = [];
    const remaining = [];
    for (const message of this.queue) {
      if (predicate(message)) {
        matches.push(message);
      } else {
        remaining.push(message);
      }
    }
    this.queue = remaining;
    return matches;
  }

  async observe(ms) {
    await new Promise((resolveObserve) => setTimeout(resolveObserve, ms));
  }

  async close() {
    await new Promise((resolveClose) => {
      this.ws.once("close", resolveClose);
      this.ws.close();
    });
    await new Promise((resolveStream) => this.stream.end(resolveStream));
  }
}

async function waitForChatStartOrError(socket, timeoutMs, label) {
  return socket.waitFor(
    (message) => message.type === "chat_started" || isCommandError(message),
    timeoutMs,
    label
  );
}

function isCommandError(message) {
  if (message.type !== "error") {
    return false;
  }
  return !isPushNotificationError(message.message);
}

function isPushNotificationError(message) {
  return message.startsWith("APNs device token") || message.includes("HANDRAIL_APNS_");
}

async function observeStartedChat(socket, result, sentAt, observeMs) {
  if (result.type === "error") {
    return {
      sentAt,
      result: "error",
      error: result.message,
      chatId: null,
      chatStartedReceived: false,
      chatStartedEventReceived: false,
      chatListContainsStartedChat: false
    };
  }

  const chatId = result.chat.id;
  await socket.observe(observeMs);
  const related = socket.drainMatching((message) =>
    (message.type === "chat_event" && message.chatId === chatId) ||
    (message.type === "chat_list" && message.chats.some((chat) => chat.id === chatId))
  );
  return {
    sentAt,
    result: "chat_started",
    chatId,
    title: result.chat.title,
    status: result.chat.status,
    chatStartedReceived: true,
    chatStartedEventReceived: related.some((message) =>
      message.type === "chat_event" && message.chatId === chatId && message.event?.kind === "chat_started"
    ),
    chatListContainsStartedChat: related.some((message) =>
      message.type === "chat_list" && message.chats.some((chat) => chat.id === chatId)
    ),
    relatedMessageTypes: related.map((message) => message.type)
  };
}

async function observeApprovalChat(socket, result, sentAt, observeMs) {
  if (result.type === "error") {
    return {
      sentAt,
      result: "error",
      error: result.message,
      chatId: null,
      chatStartedReceived: false,
      approvalRequiredReceived: false,
      waitingForApprovalInChatList: false
    };
  }

  const chatId = result.chat.id;
  await socket.observe(observeMs);
  const related = socket.drainMatching((message) =>
    (message.type === "approval_required" && message.chatId === chatId) ||
    (message.type === "chat_event" && message.chatId === chatId) ||
    (message.type === "chat_list" && message.chats.some((chat) => chat.id === chatId))
  );
  return {
    sentAt,
    result: "chat_started",
    chatId,
    title: result.chat.title,
    status: result.chat.status,
    chatStartedReceived: true,
    approvalRequiredReceived: related.some((message) => message.type === "approval_required" && message.chatId === chatId),
    waitingForApprovalInChatList: related.some((message) =>
      message.type === "chat_list" &&
      message.chats.some((chat) => chat.id === chatId && chat.status === "waiting_for_approval")
    ),
    latestListedStatus: latestListedStatus(related, chatId),
    relatedMessageTypes: related.map((message) => message.type)
  };
}

function summarizeChatList(message) {
  const counts = {};
  for (const chat of message.chats ?? []) {
    counts[chat.status] = (counts[chat.status] ?? 0) + 1;
  }
  return {
    total: message.chats?.length ?? 0,
    counts,
    newest: (message.chats ?? []).slice(0, 10).map((chat) => ({
      id: chat.id,
      status: chat.status,
      title: chat.title,
      repo: chat.repo,
      updatedAt: chat.updatedAt
    }))
  };
}

function latestListedStatus(messages, chatId) {
  let status = null;
  for (const message of messages) {
    if (message.type !== "chat_list") {
      continue;
    }
    const chat = message.chats.find((item) => item.id === chatId);
    if (chat) {
      status = chat.status;
    }
  }
  return status;
}

function classify(summary) {
  return {
    issue21: summary.startChat.chatStartedReceived
      ? "server emitted chat_started for a real start_chat; investigate iOS lastStartedChatId routing if simulator does not transition"
      : "server did not emit chat_started for a real start_chat; investigate Desktop visibility wait or app-server start path",
    issue22: summary.startChat.chatStartedEventReceived
      ? "server emitted a chat-linked chat_event; investigate iOS activity ingestion/routing if Activity lacks a chat-linked row"
      : "server did not emit the expected chat-linked chat_event; investigate ChatManager start/continue broadcast path",
    issue24: summary.approvalChat.waitingForApprovalInChatList
      ? "server emitted waiting_for_approval in chat_list; investigate iOS decode/store/UI filtering if dashboard lacks approval row"
      : summary.approvalChat.approvalRequiredReceived
        ? "server emitted approval_required but did not keep waiting_for_approval in chat_list; investigate CLI status mapping/poll overwrite"
        : "real Desktop repro did not produce an approval_required or waiting_for_approval signal through Handrail; investigate Desktop source state and CLI ingestion"
  };
}

async function snapshotCliChats(outDir, label) {
  await runCommand(outDir, `${label}-cli-chats`, "node", ["cli/dist/src/index.js", "chats"], { cwd: repoRoot });
}

async function snapshotDesktopState(outDir, label, chatId) {
  const stateDb = join(homedir(), ".codex", "state_5.sqlite");
  const logsDb = join(homedir(), ".codex", "logs_2.sqlite");
  await sqliteJson(outDir, `${label}-desktop-threads`, stateDb, [
    "SELECT id, archived, source, cwd, title, first_user_message, rollout_path,",
    "datetime(created_at, 'unixepoch') AS created_at,",
    "datetime(updated_at, 'unixepoch') AS updated_at",
    "FROM threads ORDER BY updated_at DESC, id DESC LIMIT 50"
  ].join(" "));
  await sqliteJson(outDir, `${label}-desktop-status-logs`, logsDb, [
    "SELECT id, thread_id, target, ts, ts_nanos,",
    "CASE",
    "WHEN feedback_log_body LIKE '%\"type\":\"response.failed\"%' THEN 'failed'",
    "WHEN feedback_log_body LIKE '%\"type\":\"response.completed\"%' THEN 'completed'",
    "WHEN feedback_log_body LIKE '%\"type\":\"response.in_progress\"%' THEN 'running'",
    "WHEN feedback_log_body LIKE '%\"type\":\"response.created\"%' THEN 'running'",
    "END AS inferred_status",
    "FROM logs",
    "WHERE target = 'codex_api::endpoint::responses_websocket'",
    "AND (feedback_log_body LIKE '%\"type\":\"response.failed\"%'",
    "OR feedback_log_body LIKE '%\"type\":\"response.completed\"%'",
    "OR feedback_log_body LIKE '%\"type\":\"response.in_progress\"%'",
    "OR feedback_log_body LIKE '%\"type\":\"response.created\"%')",
    "ORDER BY ts DESC, ts_nanos DESC, id DESC LIMIT 100"
  ].join(" "));

  if (chatId) {
    const threadId = chatId.replace(/^codex:/, "");
    await sqliteJson(outDir, `${label}-target-thread`, stateDb, [
      "SELECT id, archived, source, cwd, title, first_user_message, rollout_path,",
      "datetime(created_at, 'unixepoch') AS created_at,",
      "datetime(updated_at, 'unixepoch') AS updated_at",
      "FROM threads",
      `WHERE id = '${sqlString(threadId)}'`
    ].join(" "));
    await sqliteJson(outDir, `${label}-target-status-logs`, logsDb, [
      "SELECT id, thread_id, target, ts, ts_nanos, feedback_log_body",
      "FROM logs",
      `WHERE thread_id = '${sqlString(threadId)}'`,
      "ORDER BY ts DESC, ts_nanos DESC, id DESC LIMIT 50"
    ].join(" "));
  }
}

async function sqliteJson(outDir, label, dbPath, sql) {
  await runCommand(outDir, label, "sqlite3", ["-readonly", "-json", dbPath, sql], { cwd: repoRoot });
}

async function runCommand(outDir, label, command, args, options) {
  const commandRecord = { command, args, cwd: options.cwd, startedAt: new Date().toISOString() };
  await writeJson(join(outDir, `${label}.command.json`), commandRecord);
  try {
    const { stdout, stderr } = await execFileAsync(command, args, {
      cwd: options.cwd,
      maxBuffer: 20_000_000
    });
    await writeFile(join(outDir, `${label}.stdout`), stdout, "utf8");
    await writeFile(join(outDir, `${label}.stderr`), stderr, "utf8");
    await writeJson(join(outDir, `${label}.result.json`), {
      ok: true,
      finishedAt: new Date().toISOString()
    });
    return { ok: true, stdout, stderr };
  } catch (error) {
    await writeFile(join(outDir, `${label}.stdout`), error.stdout ?? "", "utf8");
    await writeFile(join(outDir, `${label}.stderr`), error.stderr ?? error.message, "utf8");
    await writeJson(join(outDir, `${label}.result.json`), {
      ok: false,
      code: error.code,
      message: error.message,
      finishedAt: new Date().toISOString()
    });
    return { ok: false, stdout: error.stdout ?? "", stderr: error.stderr ?? error.message };
  }
}

async function prepareReproDirectory() {
  await mkdir(reproRoot, { recursive: true });
  await writeFile(join(reproRoot, "README.md"), "Handrail live Desktop data repro workspace.\n", "utf8");
  await writeFile(join(reproRoot, "approval-target.txt"), "Initial approval target.\n", "utf8");
}

async function readJson(path) {
  return JSON.parse(await readFile(path, "utf8"));
}

async function writeJson(path, value) {
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function timestampForPath(date) {
  return date.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

function sqlString(value) {
  return value.replace(/'/g, "''");
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
