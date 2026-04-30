import { randomUUID } from "node:crypto";
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

export async function startCodexDesktopConversation(input: DesktopConversationInput): Promise<string> {
  const client = new CodexDesktopAppServerClient(codexDesktopAppServerPath());
  await client.connect();
  try {
    const threadId = await createCodexDesktopThread(client, input);
    client.close();
    await startCodexDesktopTurn({ threadId, cwd: input.cwd, prompt: input.prompt });
    return threadId;
  } catch (error) {
    client.close();
    throw error;
  }
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

export function codexDesktopIpcRequest(method: string, params: unknown, sourceClientId: string, requestId: string = randomUUID()): IpcRequest {
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

    const request = codexDesktopIpcRequest(method, params, this.clientId);
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

async function createCodexDesktopThread(client: CodexDesktopAppServerClient, input: DesktopConversationInput): Promise<string> {
  const result = await client.request("thread/start", codexDesktopThreadStartParams(input));
  const threadId = readThreadId(result);
  if (!threadId) {
    throw new Error("Codex Desktop app-server did not return a thread id.");
  }
  return threadId;
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

class CodexDesktopAppServerClient {
  private child: ChildProcessWithoutNullStreams | null = null;
  private buffer = "";
  private pending = new Map<string, PendingAppServerResponse>();

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

  async request(method: string, params: unknown, id: string = `${method}:${randomUUID()}`): Promise<unknown> {
    const child = this.child;
    if (!child?.stdin.writable) {
      throw new Error("Codex Desktop app-server is not connected.");
    }

    const response = await new Promise<AppServerResponse>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Timed out waiting for Codex Desktop app-server to handle ${method}.`));
      }, APP_SERVER_REQUEST_TIMEOUT_MS);
      this.pending.set(id, { resolve, reject, timer });
      child.stdin.write(`${JSON.stringify({ id, method, params })}\n`);
    });

    if (response.error) {
      throw new Error(response.error.message ?? `Codex Desktop app-server rejected ${method}.`);
    }
    return response.result;
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
    if (!message || typeof message !== "object" || !("id" in message) || typeof message.id !== "string") {
      return;
    }
    const pending = this.pending.get(message.id);
    if (!pending) {
      return;
    }
    this.pending.delete(message.id);
    clearTimeout(pending.timer);
    pending.resolve(message as AppServerResponse);
  }

  private rejectAll(error: Error): void {
    for (const [requestId, pending] of this.pending) {
      clearTimeout(pending.timer);
      pending.reject(error);
      this.pending.delete(requestId);
    }
  }
}
