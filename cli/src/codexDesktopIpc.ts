import { execFile, spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Socket, createConnection } from "node:net";
import { promisify } from "node:util";

const INITIALIZING_CLIENT_ID = "initializing-client";
const REQUEST_TIMEOUT_MS = 15_000;
const APP_SERVER_REQUEST_TIMEOUT_MS = 30_000;
const APP_SERVER_INITIALIZE_ID = "__codex_initialize__";
const DESKTOP_APP_ACTIVATE_SETTLE_MS = 1_000;
const DESKTOP_ROUTE_SETTLE_MS = 6_000;

const execFileAsync = promisify(execFile);

type IpcResponse =
  | { type: "response"; requestId: string; resultType: "success"; method?: string; result?: unknown }
  | { type: "response"; requestId: string; resultType: "error"; error: string };

interface PendingResponse {
  resolve(response: IpcResponse): void;
  reject(error: Error): void;
  timer: NodeJS.Timeout;
}

interface IpcRequest {
  type: "request";
  requestId: string;
  sourceClientId: string;
  version: number;
  method: string;
  params: unknown;
}

export interface DesktopTurnInput {
  threadId: string;
  cwd: string;
  prompt: string;
}

export interface DesktopConversationInput {
  cwd: string;
  prompt: string;
  model: string;
  reasoningEffort: string;
  accessPreset: "full_access" | "on_request" | "read_only";
}

export interface CodexDesktopAppServerConnection {
  request(method: string, params: unknown, id?: string): Promise<unknown>;
  setApprovalRequestHandler?(handler: (request: DesktopApprovalRequest) => void): void;
  setLiveEventHandler?(handler: (event: DesktopLiveEvent) => void): void;
}

export interface DesktopApprovalRequest {
  threadId: string;
  approvalId: string;
  title: string;
  summary: string;
  files: string[];
  diff: string;
  respond(decision: DesktopApprovalDecision): Promise<void>;
}

export type DesktopApprovalDecision = "accept" | "decline";

export type DesktopLiveEventKind = "turn_started" | "turn_completed" | "turn_failed" | "turn_interrupted" | "output";

export interface DesktopLiveEvent {
  threadId: string;
  kind: DesktopLiveEventKind;
  text?: string;
}

export async function startCodexDesktopConversation(
  input: DesktopConversationInput,
  onApprovalRequest?: (request: DesktopApprovalRequest) => void,
  onLiveEvent?: (event: DesktopLiveEvent) => void
): Promise<string> {
  const client = new CodexDesktopAppServerClient(codexDesktopAppServerPath());
  await client.connect();
  try {
    const threadId = await startCodexDesktopConversationOnAppServer(client, input, onApprovalRequest, onLiveEvent);
    retainCodexDesktopAppServerUntilTurnCompletes(client, threadId);
    return threadId;
  } catch (error) {
    client.close();
    throw error;
  }
}

export async function startCodexDesktopConversationOnAppServer(
  client: CodexDesktopAppServerConnection,
  input: DesktopConversationInput,
  onApprovalRequest?: (request: DesktopApprovalRequest) => void,
  onLiveEvent?: (event: DesktopLiveEvent) => void
): Promise<string> {
  if (onApprovalRequest) {
    client.setApprovalRequestHandler?.(onApprovalRequest);
  }
  if (onLiveEvent) {
    client.setLiveEventHandler?.(onLiveEvent);
  }
  const threadId = await createCodexDesktopThread(client, input);
  await startCodexDesktopAppServerTurn(client, { threadId, cwd: input.cwd, prompt: input.prompt });
  return threadId;
}

export async function startCodexDesktopTurn(input: DesktopTurnInput): Promise<void> {
  await openCodexDesktopThread(input.threadId);
  await startCodexDesktopFollowerTurn(input);
}

export function codexDesktopThreadUrl(threadId: string): string {
  return `codex://threads/${encodeURIComponent(threadId)}`;
}

export async function openCodexDesktopThread(threadId: string): Promise<void> {
  if (process.platform !== "darwin") {
    throw new Error("Opening Codex Desktop chats from Handrail is currently supported on macOS only.");
  }
  await execFileAsync("open", ["-a", "Codex"]);
  await new Promise((resolve) => setTimeout(resolve, DESKTOP_APP_ACTIVATE_SETTLE_MS));
  await execFileAsync("open", [codexDesktopThreadUrl(threadId)]);
  await new Promise((resolve) => setTimeout(resolve, DESKTOP_ROUTE_SETTLE_MS));
}

export async function openCodexDesktopApp(): Promise<void> {
  if (process.platform !== "darwin") {
    throw new Error("Opening Codex Desktop chats from Handrail is currently supported on macOS only.");
  }
  await execFileAsync("open", ["-a", "Codex"]);
  await new Promise((resolve) => setTimeout(resolve, DESKTOP_ROUTE_SETTLE_MS));
}

export async function interruptCodexDesktopTurn(threadId: string): Promise<void> {
  await openCodexDesktopThread(threadId);
  await withCodexDesktopIpc(async (client) => {
    await client.request("thread-follower-interrupt-turn", { conversationId: threadId });
  });
}

export function codexDesktopIpcSocketPath(): string {
  const uid = typeof process.getuid === "function" ? process.getuid() : null;
  return join(tmpdir(), "codex-ipc", uid == null ? "ipc.sock" : `ipc-${uid}.sock`);
}

export function codexDesktopIpcRequest(method: string, params: unknown, sourceClientId: string, requestId: string): IpcRequest {
  return {
    type: "request",
    requestId,
    sourceClientId,
    version: codexDesktopIpcRequestVersion(method),
    method,
    params
  };
}

export function codexDesktopIpcRequestVersion(method: string): number {
  return method.startsWith("thread-follower-") ? 1 : 0;
}

export function encodeCodexDesktopIpcFrame(message: unknown): Buffer {
  const json = JSON.stringify(message);
  const length = Buffer.byteLength(json);
  const frame = Buffer.alloc(4 + length);
  frame.writeUInt32LE(length, 0);
  frame.write(json, 4);
  return frame;
}

async function withCodexDesktopIpc<T>(work: (client: CodexDesktopIpcClient) => Promise<T>): Promise<T> {
  const client = new CodexDesktopIpcClient(codexDesktopIpcSocketPath());
  await client.connect();
  try {
    return await work(client);
  } finally {
    client.close();
  }
}

class CodexDesktopIpcClient {
  private socket: Socket | null = null;
  private clientId = INITIALIZING_CLIENT_ID;
  private buffer = Buffer.alloc(0);
  private pending = new Map<string, PendingResponse>();
  private nextRequestIndex = 1;

  constructor(private readonly socketPath: string) {}

  async connect(): Promise<void> {
    if (!existsSync(this.socketPath)) {
      throw new Error(`Codex Desktop IPC socket was not found at ${this.socketPath}. Open Codex Desktop and try again.`);
    }

    await new Promise<void>((resolve, reject) => {
      const socket = createConnection(this.socketPath);
      this.socket = socket;
      socket.once("connect", resolve);
      socket.once("error", reject);
      socket.on("data", (chunk) => this.read(chunk));
      socket.on("close", () => this.rejectAll("Codex Desktop IPC connection closed."));
    });

    const response = await this.request("initialize", { clientType: "handrail" });
    if (response && typeof response === "object" && "clientId" in response && typeof response.clientId === "string") {
      this.clientId = response.clientId;
    }
  }

  async request(method: string, params: unknown): Promise<unknown> {
    const socket = this.socket;
    if (!socket?.writable) {
      throw new Error("Codex Desktop IPC is not connected.");
    }

    const request = codexDesktopIpcRequest(method, params, this.clientId, this.nextRequestId());
    const frame = encodeCodexDesktopIpcFrame(request);
    socket.write(frame);

    const response = await new Promise<IpcResponse>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(request.requestId);
        reject(new Error(`Timed out waiting for Codex Desktop to handle ${method}.`));
      }, REQUEST_TIMEOUT_MS);
      this.pending.set(request.requestId, { resolve, reject, timer });
    });

    if (response.resultType === "error") {
      throw new Error(formatDesktopIpcError(method, response.error));
    }
    return response.result;
  }

  close(): void {
    this.socket?.end();
    this.socket = null;
  }

  private read(chunk: Buffer): void {
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (this.buffer.length >= 4) {
      const length = this.buffer.readUInt32LE(0);
      if (this.buffer.length < 4 + length) {
        return;
      }
      const message = JSON.parse(this.buffer.subarray(4, 4 + length).toString("utf8")) as { type?: string; requestId?: string };
      this.buffer = this.buffer.subarray(4 + length);
      if (message.type !== "response" || typeof message.requestId !== "string") {
        continue;
      }
      const pending = this.pending.get(message.requestId);
      if (!pending) {
        continue;
      }
      this.pending.delete(message.requestId);
      clearTimeout(pending.timer);
      pending.resolve(message as IpcResponse);
    }
  }

  private rejectAll(message: string): void {
    for (const [requestId, pending] of this.pending) {
      clearTimeout(pending.timer);
      pending.reject(new Error(message));
      this.pending.delete(requestId);
    }
  }

  private nextRequestId(): string {
    return `handrail-ipc-${this.nextRequestIndex++}`;
  }
}

function formatDesktopIpcError(method: string, error: string): string {
  if (error === "no-client-found") {
    return `Codex Desktop did not become ready to receive this chat after Handrail opened it, so ${method} could not be routed. Try again once the chat is visible in Codex Desktop.`;
  }
  return `Codex Desktop rejected ${method}: ${error}`;
}

export function codexDesktopAppServerPath(): string {
  return join("/Applications", "Codex.app", "Contents", "Resources", "codex");
}

export function codexDesktopThreadStartParams(input: DesktopConversationInput): {
  model: string;
  modelProvider: null;
  cwd: string;
  approvalPolicy: "never" | "on-request";
  sandbox: "danger-full-access" | "workspace-write" | "read-only";
  config: { model_reasoning_effort: string };
  personality: null;
  ephemeral: false;
  experimentalRawEvents: false;
  dynamicTools: null;
  persistExtendedHistory: false;
  serviceTier: null;
} {
  return {
    model: input.model,
    modelProvider: null,
    cwd: input.cwd,
    approvalPolicy: input.accessPreset === "full_access" ? "never" : "on-request",
    sandbox: desktopSandbox(input.accessPreset),
    config: { model_reasoning_effort: input.reasoningEffort },
    personality: null,
    ephemeral: false,
    experimentalRawEvents: false,
    dynamicTools: null,
    persistExtendedHistory: false,
    serviceTier: null
  };
}

export function codexDesktopFollowerTurnStartParams(input: DesktopTurnInput): {
  conversationId: string;
  turnStartParams: {
    input: Array<{ type: "text"; text: string; text_elements: [] }>;
    cwd: string;
  };
} {
  return {
    conversationId: input.threadId,
    turnStartParams: {
      input: [{ type: "text", text: input.prompt, text_elements: [] }],
      cwd: input.cwd
    }
  };
}

export function codexDesktopAppServerTurnStartParams(input: DesktopTurnInput): {
  threadId: string;
  input: Array<{ type: "text"; text: string; text_elements: [] }>;
  cwd: string;
} {
  return {
    threadId: input.threadId,
    input: [{ type: "text", text: input.prompt, text_elements: [] }],
    cwd: input.cwd
  };
}

async function createCodexDesktopThread(client: CodexDesktopAppServerConnection, input: DesktopConversationInput): Promise<string> {
  const result = await client.request("thread/start", codexDesktopThreadStartParams(input));
  const threadId = readThreadId(result);
  if (!threadId) {
    throw new Error("Codex Desktop app-server did not return a thread id.");
  }
  return threadId;
}

async function startCodexDesktopAppServerTurn(client: CodexDesktopAppServerConnection, input: DesktopTurnInput): Promise<void> {
  await client.request("turn/start", codexDesktopAppServerTurnStartParams(input));
}

async function startCodexDesktopFollowerTurn(input: DesktopTurnInput): Promise<void> {
  await withCodexDesktopIpc(async (client) => {
    await client.request("thread-follower-start-turn", codexDesktopFollowerTurnStartParams(input));
  });
}

function desktopSandbox(accessPreset: DesktopConversationInput["accessPreset"]): "danger-full-access" | "workspace-write" | "read-only" {
  switch (accessPreset) {
    case "full_access":
      return "danger-full-access";
    case "read_only":
      return "read-only";
    case "on_request":
      return "workspace-write";
  }
}

function readThreadId(result: unknown): string | null {
  if (!result || typeof result !== "object" || !("thread" in result)) {
    return null;
  }
  const thread = result.thread;
  if (!thread || typeof thread !== "object" || !("id" in thread) || typeof thread.id !== "string") {
    return null;
  }
  return thread.id.trim() || null;
}

type AppServerResponse =
  | { id: string; result?: unknown; error?: null }
  | { id: string; result?: unknown; error: { message?: string; code?: number } };

interface PendingAppServerResponse {
  resolve(response: AppServerResponse): void;
  reject(error: Error): void;
  timer: NodeJS.Timeout;
}

interface AppServerNotification {
  method: string;
  params?: unknown;
}

interface PendingAppServerNotification {
  predicate(notification: AppServerNotification): boolean;
  resolve(notification: AppServerNotification): void;
  reject(error: Error): void;
}

const activeCodexDesktopAppServerClients = new Set<CodexDesktopAppServerClient>();

class CodexDesktopAppServerClient {
  private child: ChildProcessWithoutNullStreams | null = null;
  private buffer = "";
  private pending = new Map<string, PendingAppServerResponse>();
  private notificationWaiters: PendingAppServerNotification[] = [];
  private approvalRequestHandler: ((request: DesktopApprovalRequest) => void) | null = null;
  private liveEventHandler: ((event: DesktopLiveEvent) => void) | null = null;
  private nextRequestIndex = 1;

  constructor(private readonly executablePath: string) {}

  async connect(): Promise<void> {
    if (!existsSync(this.executablePath)) {
      throw new Error(`Codex Desktop app-server was not found at ${this.executablePath}. Install Codex Desktop and try again.`);
    }

    const child = spawn(this.executablePath, ["app-server", "--analytics-default-enabled"], {
      env: {
        ...process.env,
        LOG_FORMAT: "json",
        RUST_LOG: process.env.RUST_LOG ?? "warn",
        CODEX_INTERNAL_ORIGINATOR_OVERRIDE: "Codex Desktop"
      },
      stdio: ["pipe", "pipe", "pipe"]
    });
    this.child = child;
    child.stdout.on("data", (chunk) => this.readStdout(chunk));
    child.stderr.on("data", () => {});
    child.once("error", (error) => this.rejectAll(error instanceof Error ? error : new Error(String(error))));
    child.once("exit", (code, signal) => this.rejectAll(new Error(`Codex Desktop app-server exited before responding (${signal ?? code ?? "unknown"}).`)));

    await this.request("initialize", {
      clientInfo: { name: "Handrail", title: "Handrail", version: "0.1.0" },
      capabilities: { experimentalApi: true, optOutNotificationMethods: [] }
    }, APP_SERVER_INITIALIZE_ID);
  }

  async request(method: string, params: unknown, id?: string): Promise<unknown> {
    const child = this.child;
    if (!child?.stdin.writable) {
      throw new Error("Codex Desktop app-server is not connected.");
    }
    const requestId = id ?? this.nextRequestId(method);

    const response = await new Promise<AppServerResponse>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(requestId);
        reject(new Error(`Timed out waiting for Codex Desktop app-server to handle ${method}.`));
      }, APP_SERVER_REQUEST_TIMEOUT_MS);
      this.pending.set(requestId, { resolve, reject, timer });
      child.stdin.write(`${JSON.stringify({ id: requestId, method, params })}\n`);
    });

    if (response.error) {
      throw new Error(response.error.message ?? `Codex Desktop app-server rejected ${method}.`);
    }
    return response.result;
  }

  setApprovalRequestHandler(handler: (request: DesktopApprovalRequest) => void): void {
    this.approvalRequestHandler = handler;
  }

  setLiveEventHandler(handler: (event: DesktopLiveEvent) => void): void {
    this.liveEventHandler = handler;
  }

  waitForNotification(predicate: PendingAppServerNotification["predicate"]): Promise<AppServerNotification> {
    return new Promise((resolve, reject) => {
      this.notificationWaiters.push({ predicate, resolve, reject });
    });
  }

  close(): void {
    const child = this.child;
    this.child = null;
    if (child && child.exitCode == null && !child.killed) {
      child.kill();
    }
    this.rejectAll(new Error("Codex Desktop app-server connection closed."));
  }

  private readStdout(chunk: Buffer): void {
    this.buffer += chunk.toString("utf8");
    for (;;) {
      const newline = this.buffer.indexOf("\n");
      if (newline < 0) {
        return;
      }
      const line = this.buffer.slice(0, newline).trim();
      this.buffer = this.buffer.slice(newline + 1);
      if (!line) {
        continue;
      }
      this.readMessage(line);
    }
  }

  private readMessage(line: string): void {
    let message: unknown;
    try {
      message = JSON.parse(line) as unknown;
    } catch {
      return;
    }
    if (!message || typeof message !== "object") {
      return;
    }
    if (!("id" in message) || typeof message.id !== "string") {
      this.readNotification(message);
      return;
    }
    const pending = this.pending.get(message.id);
    if (!pending) {
      this.readRequest(message);
      return;
    }
    this.pending.delete(message.id);
    clearTimeout(pending.timer);
    pending.resolve(message as AppServerResponse);
  }

  private readRequest(message: object): void {
    if (!("id" in message) || typeof message.id !== "string" || !("method" in message) || typeof message.method !== "string") {
      return;
    }
    if (!("params" in message)) {
      this.sendRequestError(message.id, `Codex Desktop app-server request ${message.method} did not include params.`);
      return;
    }
    const requestId = message.id;
    const approval = codexDesktopApprovalRequestFromServerRequest(
      requestId,
      message.method,
      message.params,
      (decision) => this.respondToServerRequest(requestId, { decision })
    );
    if (!approval || !this.approvalRequestHandler) {
      this.sendRequestError(message.id, `Handrail cannot handle Codex Desktop app-server request ${message.method}.`);
      return;
    }
    this.approvalRequestHandler(approval);
  }

  private readNotification(message: object): void {
    if (!("method" in message) || typeof message.method !== "string") {
      return;
    }
    const notification: AppServerNotification = {
      method: message.method,
      params: "params" in message ? message.params : undefined
    };
    const liveEvent = codexDesktopLiveEventFromNotification(notification.method, notification.params);
    if (liveEvent) {
      this.liveEventHandler?.(liveEvent);
    }
    const waiterIndex = this.notificationWaiters.findIndex((waiter) => waiter.predicate(notification));
    if (waiterIndex < 0) {
      return;
    }
    const [waiter] = this.notificationWaiters.splice(waiterIndex, 1);
    waiter.resolve(notification);
  }

  private rejectAll(error: Error): void {
    for (const [requestId, pending] of this.pending) {
      clearTimeout(pending.timer);
      pending.reject(error);
      this.pending.delete(requestId);
    }
    for (const waiter of this.notificationWaiters) {
      waiter.reject(error);
    }
    this.notificationWaiters = [];
  }

  private nextRequestId(method: string): string {
    return `${method}:${this.nextRequestIndex++}`;
  }

  private async respondToServerRequest(requestId: string, result: unknown): Promise<void> {
    const child = this.child;
    if (!child?.stdin.writable) {
      throw new Error("Codex Desktop app-server is not connected.");
    }
    child.stdin.write(`${JSON.stringify({ id: requestId, result })}\n`);
  }

  private sendRequestError(requestId: string, message: string): void {
    const child = this.child;
    if (!child?.stdin.writable) {
      return;
    }
    child.stdin.write(`${JSON.stringify({ id: requestId, error: { message } })}\n`);
  }
}

export function codexDesktopApprovalRequestFromServerRequest(
  requestId: string,
  method: string,
  params: unknown,
  respond: (decision: DesktopApprovalDecision) => Promise<void>
): DesktopApprovalRequest | null {
  if (!params || typeof params !== "object") {
    return null;
  }
  if (method === "item/commandExecution/requestApproval") {
    const threadId = readString(params, "threadId");
    const command = readString(params, "command");
    const reason = readString(params, "reason");
    if (!threadId) {
      return null;
    }
    return {
      threadId,
      approvalId: requestId,
      title: "Command approval required",
      summary: command ?? reason ?? "Codex requests permission to run a command.",
      files: [],
      diff: "",
      respond
    };
  }
  if (method === "item/fileChange/requestApproval") {
    const threadId = readString(params, "threadId");
    const grantRoot = readString(params, "grantRoot");
    const reason = readString(params, "reason");
    if (!threadId) {
      return null;
    }
    return {
      threadId,
      approvalId: requestId,
      title: "File change approval required",
      summary: reason ?? (grantRoot ? `Codex requests permission to change files under ${grantRoot}.` : "Codex requests permission to change files."),
      files: grantRoot ? [grantRoot] : [],
      diff: "",
      respond
    };
  }
  return null;
}

export function codexDesktopLiveEventFromNotification(method: string, params: unknown): DesktopLiveEvent | null {
  if (!params || typeof params !== "object") {
    return null;
  }
  const threadId = readString(params, "threadId");
  if (!threadId) {
    return null;
  }
  if (method === "turn/started") {
    return { threadId, kind: "turn_started", text: "Codex Desktop turn started." };
  }
  if (method === "turn/completed") {
    const turn = readObject(params, "turn");
    const status = turn ? readString(turn, "status") : null;
    if (status === "failed") {
      return { threadId, kind: "turn_failed", text: readTurnErrorMessage(turn as object) ?? "Codex Desktop turn failed." };
    }
    if (status === "interrupted") {
      return { threadId, kind: "turn_interrupted", text: "Codex Desktop turn was interrupted." };
    }
    return { threadId, kind: "turn_completed", text: "Codex Desktop turn completed." };
  }
  if (method === "item/agentMessage/delta") {
    const text = readString(params, "delta");
    return text ? { threadId, kind: "output", text } : null;
  }
  return null;
}

function readString(value: object, key: string): string | null {
  const fields = value as Record<string, unknown>;
  if (!(key in fields)) {
    return null;
  }
  const candidate = fields[key];
  return typeof candidate === "string" && candidate.trim() ? candidate : null;
}

function readObject(value: object, key: string): object | null {
  const fields = value as Record<string, unknown>;
  const candidate = fields[key];
  return candidate && typeof candidate === "object" ? candidate : null;
}

function readTurnErrorMessage(turn: object): string | null {
  const error = readObject(turn, "error");
  return error ? readString(error, "message") : null;
}

function retainCodexDesktopAppServerUntilTurnCompletes(client: CodexDesktopAppServerClient, threadId: string): void {
  activeCodexDesktopAppServerClients.add(client);
  void client.waitForNotification((notification) => isTurnCompletedNotification(notification, threadId))
    .catch(() => {})
    .finally(() => {
      activeCodexDesktopAppServerClients.delete(client);
      client.close();
    });
}

function isTurnCompletedNotification(notification: AppServerNotification, threadId: string): boolean {
  if (notification.method !== "turn/completed") {
    return false;
  }
  const params = notification.params;
  return !!params && typeof params === "object" && "threadId" in params && params.threadId === threadId;
}
